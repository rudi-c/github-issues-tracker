defmodule GithubIssuesTracker.CLI do

  @default_count 4

  @moduledoc """
  Handle the command line parsing and the dispatch to
  the various functions that end up generating a
  table of the last _n_ issues in a github project
  """

  def main(argv) do
    argv
      |> parse_args
      |> process
  end

  @doc """
  `argv` can be -h or --help, which returns :help.

  Otherwise it is a github user name, project name, and (optionally)
  the number of entries to format.

  Return a tuple of `{ user, project, count }` or `:help` if help was given.
  """
  def parse_args(argv) do
    parse = OptionParser.parse(argv, switches: [ help: :boolean ],
                                     aliases:  [ h:    :help ])
    case parse do
      { [ help: true ], _, _ } -> :help
      { _, [ user, project, count ], _ } -> { user, project, count }
      { _, [ user, project ], _ } -> { user, project, @default_count }
      _ -> :help
    end
  end

  def process(:help) do
    IO.puts """
    usage: issues <user> <project> [ count | #{@default_count} ]
    """
    System.halt(0)
  end

  def process({user, project, count}) do
    data =
      GithubIssuesTracker.GithubIssues.fetch(user, project)
      |> decode_response
      |> sort_into_ascending_order
      |> Enum.take(count)
      |> Enum.map(fn issue -> extract(issue) end)

    # TODO: Could make this generic
    max_id_len = Enum.max(Enum.map(data, fn {id, _, _} -> String.length("#{id}") end))
    max_time_len = Enum.max(Enum.map(data, fn {_, time, _} -> String.length(time) end))
    # max_title_len = Enum.max(Enum.map(data, fn {_, _, title} -> String.length(title) end))

    # TODO: Make table header
    data |> Enum.map(fn {id, created_at, title} ->
      right_pad("#{id}", max_id_len)
      <> " | "
      <> right_pad(created_at, max_time_len)
      <> " | "
      <> title
    end)
    |> Enum.each(fn row -> IO.puts row end)
  end

  def decode_response({:ok, body}), do: body
  def decode_response({:error, error}) do
    {_, message} = List.keyfind(error, "message", 0)
    IO.puts "Error fetching from Github: #{message}"
    System.halt(2)
  end

  def sort_into_ascending_order(list_of_issues) do
    Enum.sort list_of_issues,
              fn i1, i2 -> Map.get(i1, "created_at") <= Map.get(i2, "created_at") end
  end

  def right_pad(str, len) do
    str <> String.duplicate(" ", len - String.length(str))
  end

  def extract(issue) do
    { Map.get(issue, "id"), Map.get(issue, "created_at"), Map.get(issue, "title") }
  end
end
