defmodule Xactions.Vault do
  @moduledoc "Cloak encryption vault for encrypted fields."

  use Cloak.Vault, otp_app: :xactions
end
