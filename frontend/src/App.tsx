import { useMemo, useState } from 'react'

import './App.css'
import { BoardHeader } from './components/BoardHeader'
import { DeleteConfirmModal } from './components/DeleteConfirmModal'
import { TodoBoard } from './components/TodoBoard'
import { TodoComposer } from './components/TodoComposer'
import { TodoFilters } from './components/TodoFilters'
import { bootstrapTodoStore, useTodoStore } from './store/todoStore'
import type { CreateTodoInput, TodoItem, TodoPriority } from './types/todo'
import { BOARD_COLUMNS } from './types/todo'

const PRIORITY_OPTIONS: Array<{ value: TodoPriority; label: string }> = [
  { value: 'low', label: 'Baixa' },
  { value: 'medium', label: 'Média' },
  { value: 'high', label: 'Alta' },
]

const PRIORITY_LABEL: Record<TodoPriority, string> = {
  low: 'Baixa',
  medium: 'Média',
  high: 'Alta',
}

const PRIORITY_FILTER_OPTIONS: Array<{ value: 'all' | TodoPriority; label: string }> = [
  { value: 'all', label: 'Todas prioridades' },
  { value: 'high', label: 'Alta' },
  { value: 'medium', label: 'Média' },
  { value: 'low', label: 'Baixa' },
]

bootstrapTodoStore()

function App() {
  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [dueDate, setDueDate] = useState('')
  const [tagsText, setTagsText] = useState('')
  const [priority, setPriority] = useState<TodoPriority>('medium')
  const [todoPendingDelete, setTodoPendingDelete] = useState<TodoItem | null>(null)
  const [isDeleteModalClosing, setIsDeleteModalClosing] = useState(false)
  const [searchQuery, setSearchQuery] = useState('')
  const [priorityFilter, setPriorityFilter] = useState<'all' | TodoPriority>('all')
  const [onlyDueSoon, setOnlyDueSoon] = useState(false)

  const todos = useTodoStore((state) => state.todos)
  const isLoading = useTodoStore((state) => state.isLoading)
  const pendingRequests = useTodoStore((state) => state.pendingRequests)
  const error = useTodoStore((state) => state.error)
  const loadTodos = useTodoStore((state) => state.loadTodos)
  const addTodo = useTodoStore((state) => state.addTodo)
  const moveTodo = useTodoStore((state) => state.moveTodo)
  const updateTodo = useTodoStore((state) => state.updateTodo)
  const deleteTodo = useTodoStore((state) => state.deleteTodo)
  const clearError = useTodoStore((state) => state.clearError)

  const isSyncing = pendingRequests > 0
  const showStatsLoader = isLoading || isSyncing
  const normalizedSearch = searchQuery.trim().toLowerCase()
  const hasActiveFilters = normalizedSearch.length > 0 || priorityFilter !== 'all' || onlyDueSoon

  const filteredTodos = useMemo(
    () =>
      todos.filter((todo) => {
        if (priorityFilter !== 'all' && todo.priority !== priorityFilter) {
          return false
        }

        if (normalizedSearch.length > 0) {
          const haystack = [todo.title, todo.description ?? '', todo.tags.join(' ')]
            .join(' ')
            .toLowerCase()

          if (!haystack.includes(normalizedSearch)) {
            return false
          }
        }

        if (onlyDueSoon && !hasValidDueDate(todo.dueDate)) {
          return false
        }

        return true
      }),
    [todos, priorityFilter, normalizedSearch, onlyDueSoon]
  )

  const doneCount = useMemo(() => todos.filter((todo) => todo.status === 'done').length, [todos])

  const inProgressCount = useMemo(
    () => todos.filter((todo) => todo.status === 'in_progress').length,
    [todos]
  )

  const todoCount = useMemo(() => todos.filter((todo) => todo.status === 'todo').length, [todos])

  const completionRate = useMemo(() => {
    if (todos.length === 0) {
      return 0
    }

    const weightedDone = doneCount + inProgressCount * 0.5
    return Math.round((weightedDone / todos.length) * 100)
  }, [doneCount, inProgressCount, todos.length])

  const board = useMemo(
    () =>
      BOARD_COLUMNS.map((column) => ({
        ...column,
        todos: filteredTodos.filter((todo) => todo.status === column.status),
        total: todos.filter((todo) => todo.status === column.status).length,
      })),
    [filteredTodos, todos]
  )

  const handleCreateTodo = async (input: CreateTodoInput) => {
    await addTodo(input)

    setTitle('')
    setDescription('')
    setDueDate('')
    setTagsText('')
  }

  const clearFilters = () => {
    setSearchQuery('')
    setPriorityFilter('all')
    setOnlyDueSoon(false)
  }

  const requestDelete = (todo: TodoItem) => {
    setIsDeleteModalClosing(false)
    setTodoPendingDelete(todo)
  }

  const closeDeleteModal = () => {
    setIsDeleteModalClosing(true)
  }

  const handleDeleteModalAnimationEnd = (event: React.AnimationEvent<HTMLElement>) => {
    if (event.target !== event.currentTarget) {
      return
    }

    if (!isDeleteModalClosing) {
      return
    }

    setTodoPendingDelete(null)
    setIsDeleteModalClosing(false)
  }

  const confirmDelete = async () => {
    if (!todoPendingDelete) {
      return
    }

    await deleteTodo(todoPendingDelete.id)
    closeDeleteModal()
  }

  return (
    <section className="app-shell">
      <BoardHeader
        doneCount={doneCount}
        totalCount={todos.length}
        inProgressCount={inProgressCount}
        todoCount={todoCount}
        completionRate={completionRate}
        showStatsLoader={showStatsLoader}
        isLoading={isLoading}
        isSyncing={isSyncing}
      />

      <TodoFilters
        searchQuery={searchQuery}
        priorityFilter={priorityFilter}
        onlyDueSoon={onlyDueSoon}
        hasActiveFilters={hasActiveFilters}
        priorityFilterOptions={PRIORITY_FILTER_OPTIONS}
        onSearchChange={setSearchQuery}
        onPriorityFilterChange={setPriorityFilter}
        onOnlyDueSoonChange={setOnlyDueSoon}
        onClearFilters={clearFilters}
        filteredCount={filteredTodos.length}
        totalCount={todos.length}
      />

      <TodoComposer
        title={title}
        description={description}
        dueDate={dueDate}
        tagsText={tagsText}
        priority={priority}
        isLoading={isLoading}
        isSyncing={isSyncing}
        priorityOptions={PRIORITY_OPTIONS}
        onTitleChange={setTitle}
        onDescriptionChange={setDescription}
        onDueDateChange={setDueDate}
        onTagsTextChange={setTagsText}
        onPriorityChange={setPriority}
        onReload={loadTodos}
        onCreate={handleCreateTodo}
      />

      {error ? (
        <div className="error-banner" role="alert">
          <p>{error}</p>
          <button type="button" onClick={clearError}>
            Fechar
          </button>
        </div>
      ) : null}

      <TodoBoard
        columns={board}
        hasActiveFilters={hasActiveFilters}
        isSyncing={isSyncing}
        priorityLabel={PRIORITY_LABEL}
        onMoveTodo={moveTodo}
        onUpdateTodo={updateTodo}
        onRequestDelete={requestDelete}
      />

      {todoPendingDelete ? (
        <DeleteConfirmModal
          todo={todoPendingDelete}
          isClosing={isDeleteModalClosing}
          isSyncing={isSyncing}
          onClose={closeDeleteModal}
          onConfirm={confirmDelete}
          onAnimationEnd={handleDeleteModalAnimationEnd}
        />
      ) : null}
    </section>
  )
}

const hasValidDueDate = (isoDate: string | null): boolean => {
  if (!isoDate) {
    return false
  }

  const parsed = new Date(isoDate)
  return !Number.isNaN(parsed.getTime())
}

export default App
