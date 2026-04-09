defmodule Xactions.Encrypted.Binary do
  use Cloak.Ecto.Binary, vault: Xactions.Vault
end
