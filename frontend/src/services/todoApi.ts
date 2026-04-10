import type {
  CreateTodoInput,
  TodoItem,
  TodoPriority,
  TodoStatus,
  UpdateTodoInput,
} from '../types/todo'

type ApiTodo = {
  id: string
  title: string
  description: string | null
  done: boolean
  due_date: string | null
  priority: string
  tags: string[]
  inserted_at: string | null
  updated_at: string | null
}

type ApiListResponse = {
  data: ApiTodo[]
  meta: {
    page: number
    page_size: number
    total: number
  }
}

type ApiShowResponse = {
  data: ApiTodo
}

type ApiErrorResponse = {
  error?: {
    message?: string
    code?: string
    details?: Record<string, string[]>
  }
}

const DEFAULT_API_BASE_URL = 'http://localhost:4000/api'
const STATUS_TAG_PREFIX = 'status:'
const KNOWN_PRIORITIES: TodoPriority[] = ['low', 'medium', 'high']

const apiBaseUrl = (import.meta.env.VITE_API_BASE_URL ?? DEFAULT_API_BASE_URL).replace(/\/+$/, '')

export const listTodos = async (): Promise<TodoItem[]> => {
  const response = await request<ApiListResponse>('/todos?page=1&page_size=100')
  return response.data.map(mapApiTodoToTodoItem)
}

export const createTodo = async (input: CreateTodoInput): Promise<TodoItem> => {
  const normalizedDescription = normalizeNullableString(input.description)
  const normalizedDueDate = normalizeNullableString(input.dueDate)
  const normalizedTags = stripStatusTags(normalizeTags(input.tags ?? []))

  const payload = {
    todo: {
      title: input.title,
      description: normalizedDescription,
      due_date: normalizedDueDate,
      priority: input.priority,
      done: false,
      tags: [...normalizedTags, statusToTag('todo')],
    },
  }

  const response = await request<ApiShowResponse>('/todos', {
    method: 'POST',
    body: JSON.stringify(payload),
  })

  return mapApiTodoToTodoItem(response.data)
}

export const updateTodo = async (input: UpdateTodoInput): Promise<TodoItem> => {
  const statusPatch = buildStatusPatch(input.status, input.tags)

  const payload = {
    todo: {
      title: input.title,
      description: normalizeNullableString(input.description),
      due_date: normalizeNullableString(input.dueDate),
      priority: input.priority,
      ...statusPatch,
    },
  }

  const response = await request<ApiShowResponse>(`/todos/${input.id}`, {
    method: 'PATCH',
    body: JSON.stringify(payload),
  })

  return mapApiTodoToTodoItem(response.data)
}

export const deleteTodo = async (todoId: string): Promise<void> => {
  await request<void>(`/todos/${todoId}`, {
    method: 'DELETE',
  })
}

export const updateTodoStatus = async (
  todo: Pick<TodoItem, 'id' | 'tags'>,
  status: TodoStatus
): Promise<TodoItem> => {
  const payload = {
    todo: buildStatusPatch(status, todo.tags),
  }

  const response = await request<ApiShowResponse>(`/todos/${todo.id}`, {
    method: 'PATCH',
    body: JSON.stringify(payload),
  })

  return mapApiTodoToTodoItem(response.data)
}

const request = async <T>(path: string, init: RequestInit = {}): Promise<T> => {
  const headers = new Headers(init.headers)

  if (!headers.has('content-type') && init.body) {
    headers.set('content-type', 'application/json')
  }

  const response = await fetch(`${apiBaseUrl}${path}`, {
    ...init,
    headers,
  })

  if (!response.ok) {
    throw new Error(await readApiError(response))
  }

  if (response.status === 204) {
    return undefined as T
  }

  return (await response.json()) as T
}

const readApiError = async (response: Response): Promise<string> => {
  try {
    const payload = (await response.json()) as ApiErrorResponse

    if (payload.error?.message) {
      return payload.error.message
    }

    if (payload.error?.details) {
      const firstDetail = Object.values(payload.error.details)[0]?.[0]
      if (firstDetail) {
        return firstDetail
      }
    }

    if (payload.error?.code) {
      return payload.error.code
    }
  } catch {
    return `Request failed with status ${response.status}`
  }

  return `Request failed with status ${response.status}`
}

const mapApiTodoToTodoItem = (todo: ApiTodo): TodoItem => ({
  id: todo.id,
  title: todo.title,
  description: todo.description,
  dueDate: todo.due_date,
  priority: normalizePriority(todo.priority),
  status: deriveStatus(todo.done, todo.tags),
  tags: stripStatusTags(todo.tags ?? []),
  insertedAt: todo.inserted_at,
  updatedAt: todo.updated_at,
})

const normalizePriority = (value: string): TodoPriority =>
  KNOWN_PRIORITIES.includes(value as TodoPriority) ? (value as TodoPriority) : 'medium'

const deriveStatus = (done: boolean, tags: string[]): TodoStatus => {
  if (done) {
    return 'done'
  }

  const taggedStatus = tags.find((tag) => tag.startsWith(STATUS_TAG_PREFIX))

  if (taggedStatus === statusToTag('in_progress')) {
    return 'in_progress'
  }

  return 'todo'
}

const buildStatusPatch = (status: TodoStatus, tags: string[]) => {
  const baseTags = tags.filter((tag) => !tag.startsWith(STATUS_TAG_PREFIX))

  if (status === 'done') {
    return {
      done: true,
      tags: baseTags,
    }
  }

  return {
    done: false,
    tags: [...baseTags, statusToTag(status)],
  }
}

const statusToTag = (status: Exclude<TodoStatus, 'done'>): string => `${STATUS_TAG_PREFIX}${status}`

const normalizeNullableString = (value: string | null | undefined): string | null => {
  if (value == null) {
    return null
  }

  const normalized = value.trim()
  return normalized === '' ? null : normalized
}

const normalizeTags = (tags: string[]): string[] =>
  Array.from(new Set(tags.map((tag) => tag.trim()).filter((tag) => tag.length > 0)))

const stripStatusTags = (tags: string[]): string[] =>
  tags.filter((tag) => !tag.startsWith(STATUS_TAG_PREFIX))
