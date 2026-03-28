defmodule Onesqlx.AuditFixtures do
  @moduledoc """
  Test helpers for creating entities via the `Onesqlx.Audit` context.
  """

  alias Onesqlx.Audit

  def audit_event_fixture(scope, event_type \\ "query.executed", attrs \\ %{}) do
    {:ok, event} = Audit.record_event(scope, event_type, attrs)
    event
  end
end
