import { create } from 'zustand'

import {
  createTodo as apiCreateTodo,
  deleteTodo as apiDeleteTodo,
  listTodos,
  updateTodo as apiUpdateTodo,
  updateTodoStatus,
} from '../services/todoApi'
import type {
  CreateTodoInput,
  MoveTodoInput,
  TodoItem,
  TodoPriority,
  UpdateTodoInput,
} from '../types/todo'

type TodoState = {
  todos: TodoItem[]
  isLoading: boolean
  pendingRequests: number
  error: string | null
  loadTodos: () => Promise<void>
  addTodo: (input: CreateTodoInput) => Promise<void>
  moveTodo: (input: MoveTodoInput) => Promise<void>
  updateTodo: (input: UpdateTodoInput) => Promise<void>
  deleteTodo: (todoId: string) => Promise<void>
  clearError: () => void
}

const randomId = () =>
  typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function'
    ? crypto.randomUUID()
    : `${Date.now()}-${Math.random().toString(16).slice(2)}`

export const useTodoStore = create<TodoState>((set) => ({
  todos: [],
  isLoading: false,
  pendingRequests: 0,
  error: null,
  loadTodos: async () => {
    set({ isLoading: true, error: null })

    try {
      const todos = await listTodos()
      set({ todos, isLoading: false, error: null })
    } catch (reason) {
      set({ isLoading: false, error: toErrorMessage(reason) })
    }
  },
  addTodo: async (input) => {
    const normalizedTitle = input.title.trim()
    const priority: TodoPriority = input.priority ?? 'medium'

    if (normalizedTitle.length === 0) {
      return
    }

    const optimisticId = `local-${randomId()}`
    const optimisticTodo: TodoItem = {
      id: optimisticId,
      title: normalizedTitle,
      description: normalizeNullableString(input.description),
      dueDate: normalizeNullableString(input.dueDate),
      priority,
      status: 'todo',
      tags: normalizeTags(input.tags),
      insertedAt: null,
      updatedAt: null,
    }

    set((state) => ({
      todos: [...state.todos, optimisticTodo],
      pendingRequests: state.pendingRequests + 1,
      error: null,
    }))

    try {
      const created = await apiCreateTodo({
        title: normalizedTitle,
        priority,
        description: input.description,
        dueDate: input.dueDate,
        tags: input.tags,
      })

      set((state) => ({
        todos: state.todos.map((todo) => (todo.id === optimisticId ? created : todo)),
        pendingRequests: decrement(state.pendingRequests),
        error: null,
      }))
    } catch (reason) {
      set((state) => ({
        todos: state.todos.filter((todo) => todo.id !== optimisticId),
        pendingRequests: decrement(state.pendingRequests),
        error: toErrorMessage(reason),
      }))
    }
  },
  moveTodo: async (input) => {
    let snapshot: TodoItem[] = []
    let movedTodo: TodoItem | undefined

    set((state) => {
      snapshot = state.todos
      const nextTodos = moveTodoInBoard(state.todos, input)
      movedTodo = nextTodos.find((todo) => todo.id === input.todoId)

      return {
        todos: nextTodos,
        error: null,
      }
    })

    if (!movedTodo || input.fromStatus === input.toStatus) {
      return
    }

    set((state) => ({
      pendingRequests: state.pendingRequests + 1,
    }))

    try {
      const persisted = await updateTodoStatus(
        {
          id: movedTodo.id,
          tags: movedTodo.tags,
        },
        input.toStatus
      )

      set((state) => ({
        todos: replaceTodo(state.todos, persisted),
        pendingRequests: decrement(state.pendingRequests),
        error: null,
      }))
    } catch (reason) {
      set((state) => ({
        todos: snapshot,
        pendingRequests: decrement(state.pendingRequests),
        error: toErrorMessage(reason),
      }))
    }
  },
  updateTodo: async (input) => {
    const previous = useTodoStore.getState().todos

    const optimistic: TodoItem = {
      id: input.id,
      title: input.title,
      description: normalizeNullableString(input.description),
      dueDate: normalizeNullableString(input.dueDate),
      priority: input.priority,
      status: input.status,
      tags: normalizeTags(input.tags),
      insertedAt: previous.find((todo) => todo.id === input.id)?.insertedAt ?? null,
      updatedAt: previous.find((todo) => todo.id === input.id)?.updatedAt ?? null,
    }

    set((state) => ({
      todos: replaceTodo(state.todos, optimistic),
      pendingRequests: state.pendingRequests + 1,
      error: null,
    }))

    try {
      const persisted = await apiUpdateTodo(input)

      set((state) => ({
        todos: replaceTodo(state.todos, persisted),
        pendingRequests: decrement(state.pendingRequests),
      }))
    } catch (reason) {
      set((state) => ({
        todos: previous,
        pendingRequests: decrement(state.pendingRequests),
        error: toErrorMessage(reason),
      }))
    }
  },
  deleteTodo: async (todoId) => {
    const previous = useTodoStore.getState().todos

    set((state) => ({
      todos: state.todos.filter((todo) => todo.id !== todoId),
      pendingRequests: state.pendingRequests + 1,
      error: null,
    }))

    try {
      await apiDeleteTodo(todoId)

      set((state) => ({
        pendingRequests: decrement(state.pendingRequests),
      }))
    } catch (reason) {
      set((state) => ({
        todos: previous,
        pendingRequests: decrement(state.pendingRequests),
        error: toErrorMessage(reason),
      }))
    }
  },
  clearError: () => set({ error: null }),
}))

let didBootstrap = false

export const bootstrapTodoStore = () => {
  if (didBootstrap) {
    return
  }

  didBootstrap = true
  void useTodoStore.getState().loadTodos()
}

const moveTodoInBoard = (todos: TodoItem[], input: MoveTodoInput): TodoItem[] => {
  const { todoId, fromStatus, toStatus } = input

  const movingTodo = todos.find((todo) => todo.id === todoId && todo.status === fromStatus)

  if (!movingTodo) {
    return todos
  }

  const sourceTodos = todos.filter((todo) => !(todo.id === todoId && todo.status === fromStatus))
  const targetColumn = sourceTodos.filter((todo) => todo.status === toStatus)
  const safeIndex = clamp(input.toIndex, 0, targetColumn.length)

  const updatedTodo: TodoItem = { ...movingTodo, status: toStatus }

  const nextTargetColumn = [
    ...targetColumn.slice(0, safeIndex),
    updatedTodo,
    ...targetColumn.slice(safeIndex),
  ]

  const nonTargetTodos = sourceTodos.filter((todo) => todo.status !== toStatus)

  return [...nonTargetTodos, ...nextTargetColumn]
}

const replaceTodo = (todos: TodoItem[], replacement: TodoItem): TodoItem[] =>
  todos.map((todo) => (todo.id === replacement.id ? { ...todo, ...replacement } : todo))

const clamp = (value: number, min: number, max: number) => Math.min(Math.max(value, min), max)

const decrement = (value: number) => Math.max(0, value - 1)

const normalizeNullableString = (value: string | null | undefined): string | null => {
  if (value == null) {
    return null
  }

  const normalized = value.trim()
  return normalized === '' ? null : normalized
}

const normalizeTags = (tags: string[] | undefined): string[] => {
  if (!tags) {
    return []
  }

  return Array.from(
    new Set(
      tags
        .map((tag) => tag.trim())
        .filter((tag) => tag.length > 0)
        .filter((tag) => !tag.startsWith('status:'))
    )
  )
}

const toErrorMessage = (reason: unknown): string =>
  reason instanceof Error ? reason.message : 'Erro inesperado ao sincronizar tarefas.'
