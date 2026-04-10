import type { TodoPriority } from '../types/todo'

type TodoFiltersProps = {
  searchQuery: string
  priorityFilter: 'all' | TodoPriority
  onlyDueSoon: boolean
  hasActiveFilters: boolean
  priorityFilterOptions: Array<{ value: 'all' | TodoPriority; label: string }>
  onSearchChange: (value: string) => void
  onPriorityFilterChange: (value: 'all' | TodoPriority) => void
  onOnlyDueSoonChange: (value: boolean) => void
  onClearFilters: () => void
  filteredCount: number
  totalCount: number
}

export function TodoFilters({
  searchQuery,
  priorityFilter,
  onlyDueSoon,
  hasActiveFilters,
  priorityFilterOptions,
  onSearchChange,
  onPriorityFilterChange,
  onOnlyDueSoonChange,
  onClearFilters,
  filteredCount,
  totalCount,
}: TodoFiltersProps) {
  return (
    <>
      <section className="filters" aria-label="Filtros da board">
        <input
          value={searchQuery}
          onChange={(event) => onSearchChange(event.target.value)}
          placeholder="Buscar por título, descrição ou tag"
          aria-label="Buscar tarefas"
        />

        <select
          value={priorityFilter}
          onChange={(event) => onPriorityFilterChange(event.target.value as 'all' | TodoPriority)}
          aria-label="Filtrar por prioridade"
        >
          {priorityFilterOptions.map((option) => (
            <option key={option.value} value={option.value}>
              {option.label}
            </option>
          ))}
        </select>

        <label className="due-toggle">
          <input
            type="checkbox"
            checked={onlyDueSoon}
            onChange={(event) => onOnlyDueSoonChange(event.target.checked)}
          />
          Apenas com prazo próximo/atrasado
        </label>

        {hasActiveFilters ? (
          <button type="button" className="btn btn-ghost" onClick={onClearFilters}>
            Limpar filtros
          </button>
        ) : null}
      </section>

      {hasActiveFilters ? (
        <p className="hint" role="status">
          Exibindo {filteredCount} de {totalCount} tarefas. Desative os filtros para arrastar
          cartões.
        </p>
      ) : null}
    </>
  )
}
