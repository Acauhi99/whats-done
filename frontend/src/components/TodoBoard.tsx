import { useState } from 'react'

import type {
  MoveTodoInput,
  TodoItem,
  TodoPriority,
  TodoStatus,
  UpdateTodoInput,
} from '../types/todo'

type DragContext = {
  todoId: string
  fromStatus: TodoStatus
}

type EditDraft = {
  title: string
  description: string
  dueDate: string
  priority: TodoPriority
  tagsText: string
}

type BoardColumn = {
  status: TodoStatus
  label: string
  todos: TodoItem[]
  total: number
}

type TodoBoardProps = {
  columns: BoardColumn[]
  hasActiveFilters: boolean
  isSyncing: boolean
  priorityLabel: Record<TodoPriority, string>
  onMoveTodo: (input: MoveTodoInput) => Promise<void>
  onUpdateTodo: (input: UpdateTodoInput) => Promise<void>
  onRequestDelete: (todo: TodoItem) => void
}

export function TodoBoard({
  columns,
  hasActiveFilters,
  isSyncing,
  priorityLabel,
  onMoveTodo,
  onUpdateTodo,
  onRequestDelete,
}: TodoBoardProps) {
  const [dragging, setDragging] = useState<DragContext | null>(null)
  const [dropTarget, setDropTarget] = useState<TodoStatus | null>(null)
  const [editingTodoId, setEditingTodoId] = useState<string | null>(null)
  const [editDraft, setEditDraft] = useState<EditDraft | null>(null)

  const canDrag = !hasActiveFilters && editingTodoId === null

  const handleDragStart = (todoId: string, fromStatus: TodoStatus) => {
    setDragging({ todoId, fromStatus })
  }

  const handleDrop = async (toStatus: TodoStatus, toIndex: number) => {
    if (!dragging || hasActiveFilters) {
      return
    }

    await onMoveTodo({
      todoId: dragging.todoId,
      fromStatus: dragging.fromStatus,
      toStatus,
      toIndex,
    })

    setDragging(null)
    setDropTarget(null)
  }

  const beginEdit = (todo: TodoItem) => {
    setEditingTodoId(todo.id)
    setEditDraft({
      title: todo.title,
      description: todo.description ?? '',
      dueDate: fromIsoToDateInput(todo.dueDate),
      priority: todo.priority,
      tagsText: todo.tags.join(', '),
    })
  }

  const cancelEdit = () => {
    setEditingTodoId(null)
    setEditDraft(null)
  }

  const saveEdit = async (todo: TodoItem) => {
    if (!editDraft) {
      return
    }

    await onUpdateTodo({
      id: todo.id,
      title: editDraft.title,
      description: editDraft.description,
      dueDate: toIsoFromDateInput(editDraft.dueDate),
      priority: editDraft.priority,
      tags: parseTags(editDraft.tagsText),
      status: todo.status,
    })

    cancelEdit()
  }

  return (
    <div className="board">
      {columns.map((column) => (
        <section
          key={column.status}
          className={`column column--${column.status} ${
            dropTarget === column.status && canDrag ? 'is-drop-target' : ''
          }`}
          onDragOver={(event) => {
            event.preventDefault()
            if (canDrag) {
              setDropTarget(column.status)
            }
          }}
          onDrop={() => void handleDrop(column.status, column.todos.length)}
        >
          <header className="column-header">
            <h2>{column.label}</h2>
            <span>
              {column.todos.length}
              {hasActiveFilters ? `/${column.total}` : ''}
            </span>
          </header>

          <ul className="column-list">
            {column.todos.length === 0 ? (
              <li className="column-empty">
                {hasActiveFilters
                  ? 'Nenhuma tarefa encontrada com os filtros atuais.'
                  : 'Arraste uma tarefa para esta coluna.'}
              </li>
            ) : null}

            {column.todos.map((todo, index) => {
              const isEditing = editingTodoId === todo.id && editDraft !== null
              const due = duePresentation(todo.dueDate)

              return (
                <li
                  key={todo.id}
                  className={`card priority-${todo.priority} ${
                    dragging?.todoId === todo.id ? 'is-dragging' : ''
                  }`}
                  draggable={!isEditing && canDrag}
                  onDragStart={() => handleDragStart(todo.id, todo.status)}
                  onDragEnd={() => {
                    setDragging(null)
                    setDropTarget(null)
                  }}
                  onDragOver={(event) => event.preventDefault()}
                  onDrop={(event) => {
                    event.stopPropagation()
                    void handleDrop(column.status, index)
                  }}
                >
                  {isEditing ? (
                    <form
                      className="card-edit"
                      onSubmit={(event) => {
                        event.preventDefault()
                        void saveEdit(todo)
                      }}
                      onKeyDown={(event) => {
                        if (event.key === 'Escape') {
                          event.preventDefault()
                          cancelEdit()
                        }
                      }}
                    >
                      <input
                        value={editDraft.title}
                        onChange={(event) =>
                          setEditDraft((prev) =>
                            prev
                              ? {
                                  ...prev,
                                  title: event.target.value,
                                }
                              : prev
                          )
                        }
                        placeholder="Título"
                      />
                      <input
                        value={editDraft.description}
                        onChange={(event) =>
                          setEditDraft((prev) =>
                            prev
                              ? {
                                  ...prev,
                                  description: event.target.value,
                                }
                              : prev
                          )
                        }
                        placeholder="Descrição"
                      />
                      <input
                        type="date"
                        value={editDraft.dueDate}
                        onChange={(event) =>
                          setEditDraft((prev) =>
                            prev
                              ? {
                                  ...prev,
                                  dueDate: event.target.value,
                                }
                              : prev
                          )
                        }
                      />
                      <input
                        value={editDraft.tagsText}
                        onChange={(event) =>
                          setEditDraft((prev) =>
                            prev
                              ? {
                                  ...prev,
                                  tagsText: event.target.value,
                                }
                              : prev
                          )
                        }
                        placeholder="Tags"
                      />
                      <select
                        value={editDraft.priority}
                        onChange={(event) =>
                          setEditDraft((prev) =>
                            prev
                              ? {
                                  ...prev,
                                  priority: event.target.value as TodoPriority,
                                }
                              : prev
                          )
                        }
                      >
                        <option value="low">Baixa</option>
                        <option value="medium">Média</option>
                        <option value="high">Alta</option>
                      </select>
                      <div className="card-actions">
                        <button type="submit" className="btn btn-primary" disabled={isSyncing}>
                          Salvar
                        </button>
                        <button type="button" className="btn btn-ghost" onClick={cancelEdit}>
                          Cancelar
                        </button>
                      </div>
                    </form>
                  ) : (
                    <>
                      <div className="card-main">
                        <p className="card-title">{todo.title}</p>
                        {todo.description ? (
                          <p className="card-description">{todo.description}</p>
                        ) : null}
                        {due ? (
                          <p className={`card-meta due-pill ${due.tone}`}>{due.label}</p>
                        ) : null}
                        {todo.tags.length > 0 ? (
                          <ul className="tag-list" aria-label="Tags da tarefa">
                            {todo.tags.map((tag) => (
                              <li key={tag}>{tag}</li>
                            ))}
                          </ul>
                        ) : null}
                      </div>

                      <div className="card-side">
                        <span className="priority-tag">{priorityLabel[todo.priority]}</span>
                        <div className="card-actions">
                          <button
                            type="button"
                            className="btn btn-ghost"
                            onClick={() => beginEdit(todo)}
                            disabled={isSyncing}
                          >
                            Editar
                          </button>
                          <button
                            type="button"
                            className="btn btn-ghost"
                            onClick={() => onRequestDelete(todo)}
                            disabled={isSyncing}
                          >
                            Excluir
                          </button>
                        </div>
                      </div>
                    </>
                  )}
                </li>
              )
            })}
          </ul>
        </section>
      ))}
    </div>
  )
}

type DuePresentation = {
  label: string
  tone: 'tone-alert' | 'tone-warn' | 'tone-info'
}

const duePresentation = (isoDate: string | null): DuePresentation | null => {
  if (!isoDate) {
    return null
  }

  const parsed = new Date(isoDate)

  if (Number.isNaN(parsed.getTime())) {
    return {
      label: `Prazo: ${isoDate}`,
      tone: 'tone-info',
    }
  }

  const today = new Date()
  const now = Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate())
  const due = Date.UTC(parsed.getUTCFullYear(), parsed.getUTCMonth(), parsed.getUTCDate())
  const diffDays = Math.floor((due - now) / 86_400_000)

  if (diffDays < 0) {
    return {
      label: `Atrasada (${formatDate(isoDate)})`,
      tone: 'tone-alert',
    }
  }

  if (diffDays <= 2) {
    return {
      label: `Prazo próximo (${formatDate(isoDate)})`,
      tone: 'tone-warn',
    }
  }

  return {
    label: `Prazo: ${formatDate(isoDate)}`,
    tone: 'tone-info',
  }
}

const parseTags = (value: string): string[] =>
  Array.from(
    new Set(
      value
        .split(',')
        .map((tag) => tag.trim())
        .filter((tag) => tag.length > 0)
    )
  )

const toIsoFromDateInput = (value: string): string | null => {
  if (value.trim() === '') {
    return null
  }

  return `${value}T00:00:00Z`
}

const fromIsoToDateInput = (value: string | null): string => {
  if (!value) {
    return ''
  }

  return value.slice(0, 10)
}

const formatDate = (value: string): string => {
  const date = new Date(value)

  if (Number.isNaN(date.getTime())) {
    return value
  }

  return date.toLocaleDateString('pt-BR')
}
