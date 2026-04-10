export type TodoPriority = 'low' | 'medium' | 'high'

export type TodoStatus = 'todo' | 'in_progress' | 'done'

export type TodoItem = {
  id: string
  title: string
  description: string | null
  dueDate: string | null
  priority: TodoPriority
  status: TodoStatus
  tags: string[]
  insertedAt: string | null
  updatedAt: string | null
}

export type CreateTodoInput = {
  title: string
  priority: TodoPriority
  description?: string | null
  dueDate?: string | null
  tags?: string[]
}

export type UpdateTodoInput = {
  id: string
  title: string
  description: string | null
  dueDate: string | null
  priority: TodoPriority
  tags: string[]
  status: TodoStatus
}

export type MoveTodoInput = {
  todoId: string
  fromStatus: TodoStatus
  toStatus: TodoStatus
  toIndex: number
}

export const BOARD_COLUMNS: Array<{ status: TodoStatus; label: string }> = [
  { status: 'todo', label: 'To Do' },
  { status: 'in_progress', label: 'In Progress' },
  { status: 'done', label: 'Done' },
]
