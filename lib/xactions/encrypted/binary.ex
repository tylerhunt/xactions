defmodule Xactions.Encrypted.Binary do
  @moduledoc "Ecto type for AES-encrypted binary fields via Cloak."

  use Cloak.Ecto.Binary, vault: Xactions.Vault
end
