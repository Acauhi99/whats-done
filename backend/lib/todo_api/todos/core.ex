defmodule TodoApi.Todos.Core do
  @moduledoc """
  Functional core for Todo validation and transformations.
  """

  alias TodoApi.Todos.Todo

  @priorities ~w(low medium high)a

  @spec create(map(), DateTime.t()) :: {:ok, Todo.t()} | {:error, {:validation, map()}}
  def create(attrs, now \\ DateTime.utc_now()) do
    {title, errors} = accumulate_result(validate_title(attrs), %{})
    {description, errors} = accumulate_result(validate_description(attrs), errors)
    {done, errors} = accumulate_result(validate_done(attrs), errors)
    {due_date, errors} = accumulate_result(validate_due_date(attrs), errors)
    {priority, errors} = accumulate_result(validate_priority(attrs), errors)
    {tags, errors} = accumulate_result(validate_tags(attrs), errors)

    if map_size(errors) == 0 do
      {:ok,
       %Todo{
         title: title,
         description: description,
         done: done,
         due_date: due_date,
         priority: priority,
         tags: tags,
         inserted_at: now,
         updated_at: now
       }}
    else
      {:error, {:validation, errors}}
    end
  end

  @spec update(Todo.t(), map(), DateTime.t()) :: {:ok, Todo.t()} | {:error, {:validation, map()}}
  def update(%Todo{} = todo, attrs, now \\ DateTime.utc_now()) do
    {title, errors} = accumulate_result(validate_optional_title(attrs, todo.title), %{})

    {description, errors} =
      accumulate_result(validate_optional_description(attrs, todo.description), errors)

    {done, errors} = accumulate_result(validate_optional_done(attrs, todo.done), errors)

    {due_date, errors} =
      accumulate_result(validate_optional_due_date(attrs, todo.due_date), errors)

    {priority, errors} =
      accumulate_result(validate_optional_priority(attrs, todo.priority), errors)

    {tags, errors} = accumulate_result(validate_optional_tags(attrs, todo.tags), errors)

    if map_size(errors) == 0 do
      {:ok,
       %Todo{
         todo
         | title: title,
           description: description,
           done: done,
           due_date: due_date,
           priority: priority,
           tags: tags,
           updated_at: now
       }}
    else
      {:error, {:validation, errors}}
    end
  end

  @spec normalize_filters(map()) :: {:ok, map()} | {:error, {:validation, map()}}
  def normalize_filters(params) do
    {page, errors} = accumulate_result(validate_page(params), %{})
    {page_size, errors} = accumulate_result(validate_page_size(params), errors)
    {done, errors} = accumulate_result(validate_filter_done(params), errors)
    {priority, errors} = accumulate_result(validate_filter_priority(params), errors)
    {q, errors} = accumulate_result(validate_filter_q(params), errors)
    {tags, errors} = accumulate_result(validate_filter_tags(params), errors)

    if map_size(errors) == 0 do
      {:ok,
       %{
         page: page,
         page_size: page_size,
         done: done,
         priority: priority,
         q: q,
         tags: tags
       }}
    else
      {:error, {:validation, errors}}
    end
  end

  defp validate_title(attrs) do
    case get_attr(attrs, :title) do
      nil ->
        {:error, %{title: ["is required"]}}

      title when is_binary(title) ->
        normalized = String.trim(title)

        cond do
          normalized == "" ->
            {:error, %{title: ["cannot be empty"]}}

          String.length(normalized) > 160 ->
            {:error, %{title: ["must have at most 160 characters"]}}

          true ->
            {:ok, normalized}
        end

      _ ->
        {:error, %{title: ["must be a string"]}}
    end
  end

  defp validate_optional_title(attrs, fallback) do
    if has_attr?(attrs, :title) do
      validate_title(attrs)
    else
      {:ok, fallback}
    end
  end

  defp validate_description(attrs) do
    case get_attr(attrs, :description) do
      nil ->
        {:ok, nil}

      description when is_binary(description) ->
        normalized = String.trim(description)

        if String.length(normalized) <= 1000 do
          {:ok, if(normalized == "", do: nil, else: normalized)}
        else
          {:error, %{description: ["must have at most 1000 characters"]}}
        end

      _ ->
        {:error, %{description: ["must be a string"]}}
    end
  end

  defp validate_optional_description(attrs, fallback) do
    if has_attr?(attrs, :description) do
      validate_description(attrs)
    else
      {:ok, fallback}
    end
  end

  defp validate_done(attrs) do
    case get_attr(attrs, :done, false) do
      done when is_boolean(done) -> {:ok, done}
      _ -> {:error, %{done: ["must be a boolean"]}}
    end
  end

  defp validate_optional_done(attrs, fallback) do
    if has_attr?(attrs, :done) do
      validate_done(attrs)
    else
      {:ok, fallback}
    end
  end

  defp validate_due_date(attrs) do
    case get_attr(attrs, :due_date) do
      nil ->
        {:ok, nil}

      date when is_binary(date) ->
        case DateTime.from_iso8601(date) do
          {:ok, datetime, _offset} -> {:ok, datetime}
          _ -> {:error, %{due_date: ["must be an ISO8601 datetime"]}}
        end

      _ ->
        {:error, %{due_date: ["must be an ISO8601 string"]}}
    end
  end

  defp validate_optional_due_date(attrs, fallback) do
    if has_attr?(attrs, :due_date) do
      validate_due_date(attrs)
    else
      {:ok, fallback}
    end
  end

  defp validate_priority(attrs) do
    case get_attr(attrs, :priority, :medium) do
      priority when priority in @priorities ->
        {:ok, priority}

      priority when is_binary(priority) ->
        case safe_to_existing_atom(priority) do
          {:ok, maybe_priority} when maybe_priority in @priorities ->
            {:ok, maybe_priority}

          _ ->
            {:error, %{priority: ["must be low, medium or high"]}}
        end

      _ ->
        {:error, %{priority: ["must be low, medium or high"]}}
    end
  end

  defp validate_optional_priority(attrs, fallback) do
    if has_attr?(attrs, :priority) do
      validate_priority(attrs)
    else
      {:ok, fallback}
    end
  end

  defp validate_tags(attrs) do
    case get_attr(attrs, :tags, []) do
      tags when is_list(tags) ->
        normalized =
          tags
          |> Enum.filter(&is_binary/1)
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))
          |> Enum.uniq()

        if length(normalized) <= 20 do
          {:ok, normalized}
        else
          {:error, %{tags: ["must contain at most 20 tags"]}}
        end

      _ ->
        {:error, %{tags: ["must be a list of strings"]}}
    end
  end

  defp validate_optional_tags(attrs, fallback) do
    if has_attr?(attrs, :tags) do
      validate_tags(attrs)
    else
      {:ok, fallback}
    end
  end

  defp validate_page(params) do
    case parse_positive_int(get_attr(params, :page), 1) do
      {:ok, page} -> {:ok, page}
      :error -> {:error, %{page: ["must be a positive integer"]}}
    end
  end

  defp validate_page_size(params) do
    case parse_positive_int(get_attr(params, :page_size), 20) do
      {:ok, page_size} when page_size <= 100 -> {:ok, page_size}
      {:ok, _} -> {:error, %{page_size: ["must be less than or equal to 100"]}}
      :error -> {:error, %{page_size: ["must be a positive integer"]}}
    end
  end

  defp validate_filter_done(params) do
    case get_attr(params, :done) do
      nil -> {:ok, nil}
      "true" -> {:ok, true}
      "false" -> {:ok, false}
      done when is_boolean(done) -> {:ok, done}
      _ -> {:error, %{done: ["must be true or false"]}}
    end
  end

  defp validate_filter_priority(params) do
    case get_attr(params, :priority) do
      nil ->
        {:ok, nil}

      priority when priority in @priorities ->
        {:ok, priority}

      priority when is_binary(priority) ->
        case safe_to_existing_atom(priority) do
          {:ok, value} when value in @priorities -> {:ok, value}
          _ -> {:error, %{priority: ["must be low, medium or high"]}}
        end

      _ ->
        {:error, %{priority: ["must be low, medium or high"]}}
    end
  end

  defp validate_filter_q(params) do
    case get_attr(params, :q) do
      nil -> {:ok, nil}
      q when is_binary(q) -> {:ok, String.trim(q)}
      _ -> {:error, %{q: ["must be a string"]}}
    end
  end

  defp validate_filter_tags(params) do
    case get_attr(params, :tags) do
      nil ->
        {:ok, []}

      tags when is_binary(tags) ->
        normalized =
          tags
          |> String.split(",", trim: true)
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))
          |> Enum.uniq()

        {:ok, normalized}

      tags when is_list(tags) ->
        normalized =
          tags
          |> Enum.filter(&is_binary/1)
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))
          |> Enum.uniq()

        {:ok, normalized}

      _ ->
        {:error, %{tags: ["must be a comma-separated string or string list"]}}
    end
  end

  defp parse_positive_int(nil, default), do: {:ok, default}

  defp parse_positive_int(value, _default) when is_integer(value) and value > 0, do: {:ok, value}

  defp parse_positive_int(value, _default) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} when int > 0 -> {:ok, int}
      _ -> :error
    end
  end

  defp parse_positive_int(_value, _default), do: :error

  defp accumulate_result({:ok, value}, errors), do: {value, errors}

  defp accumulate_result({:error, validation_errors}, errors) do
    {nil, merge_errors(errors, validation_errors)}
  end

  defp merge_errors(acc, incoming) do
    Map.merge(acc, incoming, fn _field, left, right ->
      (left ++ right)
      |> Enum.uniq()
    end)
  end

  defp safe_to_existing_atom(value) do
    try do
      {:ok, String.to_existing_atom(value)}
    rescue
      ArgumentError -> :error
    end
  end

  defp get_attr(attrs, key, default \\ nil) do
    Map.get(attrs, key, Map.get(attrs, Atom.to_string(key), default))
  end

  defp has_attr?(attrs, key) do
    Map.has_key?(attrs, key) or Map.has_key?(attrs, Atom.to_string(key))
  end
end
