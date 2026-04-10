import type { CreateTodoInput, TodoPriority } from '../types/todo'

type TodoComposerProps = {
  title: string
  description: string
  dueDate: string
  tagsText: string
  priority: TodoPriority
  isLoading: boolean
  isSyncing: boolean
  priorityOptions: Array<{ value: TodoPriority; label: string }>
  onTitleChange: (value: string) => void
  onDescriptionChange: (value: string) => void
  onDueDateChange: (value: string) => void
  onTagsTextChange: (value: string) => void
  onPriorityChange: (value: TodoPriority) => void
  onReload: () => Promise<void> | void
  onCreate: (input: CreateTodoInput) => Promise<void> | void
}

export function TodoComposer({
  title,
  description,
  dueDate,
  tagsText,
  priority,
  isLoading,
  isSyncing,
  priorityOptions,
  onTitleChange,
  onDescriptionChange,
  onDueDateChange,
  onTagsTextChange,
  onPriorityChange,
  onReload,
  onCreate,
}: TodoComposerProps) {
  return (
    <form
      className="composer"
      onSubmit={(event) => {
        event.preventDefault()

        void onCreate({
          title,
          description,
          dueDate: toIsoFromDateInput(dueDate),
          tags: parseTags(tagsText),
          priority,
        })
      }}
    >
      <input
        value={title}
        onChange={(event) => onTitleChange(event.target.value)}
        placeholder="Título da tarefa"
        aria-label="Título da tarefa"
      />
      <input
        value={description}
        onChange={(event) => onDescriptionChange(event.target.value)}
        placeholder="Descrição"
        aria-label="Descrição da tarefa"
      />
      <input
        type="date"
        value={dueDate}
        onChange={(event) => onDueDateChange(event.target.value)}
        aria-label="Data limite"
      />
      <input
        value={tagsText}
        onChange={(event) => onTagsTextChange(event.target.value)}
        placeholder="tags por vírgula"
        aria-label="Tags"
      />

      <select
        value={priority}
        onChange={(event) => onPriorityChange(event.target.value as TodoPriority)}
        aria-label="Prioridade da tarefa"
      >
        {priorityOptions.map((option) => (
          <option key={option.value} value={option.value}>
            {option.label}
          </option>
        ))}
      </select>

      <div className="composer-actions">
        <button
          type="submit"
          className="btn btn-primary"
          disabled={isSyncing || title.trim().length === 0}
        >
          Adicionar
        </button>

        <button
          type="button"
          className="btn btn-ghost"
          onClick={() => void onReload()}
          disabled={isLoading}
        >
          Recarregar
        </button>
      </div>
    </form>
  )
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
