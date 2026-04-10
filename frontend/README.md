# Whats Done Frontend

## O que este projeto faz
Este frontend oferece uma interface Kanban para criar, editar, mover e excluir tarefas consumindo a API do backend.

A aplicação inclui:
- Board com colunas To Do, In Progress e Done.
- Drag and drop entre colunas.
- Filtros por texto, prioridade e prazo.
- Edição inline de tarefa.
- Modal de confirmação para exclusão.
- Indicadores de progresso no topo.

## Como este frontend está organizado
A interface foi componentizada por responsabilidade de UI:
- `BoardHeader`: título e métricas.
- `TodoFilters`: filtros e indicação de resultado filtrado.
- `TodoComposer`: formulário de criação.
- `TodoBoard`: renderização das colunas, cards e edição inline.
- `DeleteConfirmModal`: confirmação de exclusão.

Estado e integração:
- `store/todoStore.ts`: estado global e ações assíncronas.
- `services/todoApi.ts`: cliente HTTP tipado para a API.
- `types/todo.ts`: contratos de tipos do domínio.

## Tech stack
- React 19.2
- TypeScript
- Vite 8
- Zustand
- CSS puro
- ESLint + Prettier

## Como rodar
### Opção 1: Docker Compose (recomendado)
No diretório raiz do monorepo:
```bash
docker compose up -d --build
```

Frontend disponível em:
- `http://localhost:5173`

Se a porta `5173` estiver ocupada:
```bash
FRONTEND_PORT=5174 docker compose up -d --build
```

Com Compose, a URL da API usada no build do frontend pode ser sobrescrita com:
```bash
VITE_API_BASE_URL=http://localhost:4000/api docker compose up -d --build
```

### Opção 2: Local (sem Docker)
No diretório `frontend`:
```bash
pnpm install
pnpm dev
```

A URL da API é configurada por `VITE_API_BASE_URL`.
Arquivo de exemplo:
- `frontend/.env.example`

Exemplo:
```bash
cp .env.example .env
pnpm dev
```

## Comandos úteis
No diretório `frontend`:
```bash
pnpm lint
pnpm typecheck
pnpm build
pnpm format
```

## Build e entrega em Docker
O frontend é dockerizado com build multi-stage:
1. Stage Node: instala dependências e gera `dist/`.
2. Stage Nginx: serve os arquivos estáticos com fallback para SPA.

Arquivos relacionados:
- `frontend/Dockerfile`
- `frontend/nginx.conf`
- `frontend/.dockerignore`
