defmodule Backoffice.Guardian.JWT do
  @moduledoc false
  @behaviour Backoffice.Guardian.ClaimValidation

  use Backoffice.Guardian.ClaimValidation

  def validate_claim(_, _, _), do: :ok
end
