import type { TodoItem } from '../types/todo'

type DeleteConfirmModalProps = {
  todo: TodoItem
  isClosing: boolean
  isSyncing: boolean
  onClose: () => void
  onConfirm: () => Promise<void> | void
  onAnimationEnd: (event: React.AnimationEvent<HTMLElement>) => void
}

export function DeleteConfirmModal({
  todo,
  isClosing,
  isSyncing,
  onClose,
  onConfirm,
  onAnimationEnd,
}: DeleteConfirmModalProps) {
  return (
    <div
      className={`modal-backdrop ${isClosing ? 'is-closing' : 'is-open'}`}
      role="presentation"
      tabIndex={-1}
      onKeyDown={(event) => {
        if (event.key === 'Escape') {
          onClose()
        }
      }}
    >
      <section
        className={`confirm-modal ${isClosing ? 'is-closing' : 'is-open'}`}
        role="dialog"
        aria-modal="true"
        aria-labelledby="confirm-delete-title"
        aria-describedby="confirm-delete-description"
        onAnimationEnd={onAnimationEnd}
        onClick={(event) => event.stopPropagation()}
      >
        <h3 id="confirm-delete-title">Confirmar exclusão</h3>
        <p id="confirm-delete-description">
          Tem certeza que deseja excluir a tarefa "{todo.title}"?
        </p>

        <div className="confirm-actions">
          <button type="button" className="btn btn-ghost" onClick={onClose}>
            Cancelar
          </button>
          <button
            type="button"
            className="btn btn-primary"
            onClick={() => void onConfirm()}
            disabled={isSyncing}
          >
            Excluir tarefa
          </button>
        </div>
      </section>
    </div>
  )
}
