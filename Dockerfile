FROM elixir:1.19-alpine

RUN apk add --no-cache build-base git

ENV MIX_ENV=dev

WORKDIR /app/backend

COPY backend/mix.exs backend/mix.lock ./
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get --only ${MIX_ENV}

COPY backend/ ./

EXPOSE 4000

CMD ["mix", "phx.server"]
