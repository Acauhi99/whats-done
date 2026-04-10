type BoardHeaderProps = {
  doneCount: number
  totalCount: number
  inProgressCount: number
  todoCount: number
  completionRate: number
  showStatsLoader: boolean
  isLoading: boolean
  isSyncing: boolean
}

export function BoardHeader({
  doneCount,
  totalCount,
  inProgressCount,
  todoCount,
  completionRate,
  showStatsLoader,
  isLoading,
  isSyncing,
}: BoardHeaderProps) {
  return (
    <header className="headline">
      <div>
        <p className="eyebrow">Whats Done</p>
        <h1>Productivity board</h1>
        <p className="subtitle">
          Fluxo visual para planejar, executar e concluir tarefas sem friccao.
        </p>
      </div>

      <div className="stats">
        {showStatsLoader ? (
          <div
            className="stats-loader"
            role="status"
            aria-live="polite"
            aria-label="Atualizando métricas"
          >
            <span className="stats-skeleton stats-skeleton-wide" />
            <span className="stats-skeleton stats-skeleton-short" />
          </div>
        ) : (
          <>
            <p>
              <strong>{doneCount}</strong> de <strong>{totalCount}</strong> concluídas |{' '}
              <strong>{inProgressCount}</strong> em andamento | <strong>{todoCount}</strong> a fazer
            </p>
            <p>
              <strong>{completionRate}%</strong> de progresso
            </p>
          </>
        )}

        {isLoading ? <span className="chip">Carregando...</span> : null}
        {isSyncing ? <span className="chip">Sincronizando...</span> : null}
      </div>
    </header>
  )
}
