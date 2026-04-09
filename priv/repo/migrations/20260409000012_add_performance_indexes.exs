defmodule Xactions.Repo.Migrations.AddPerformanceIndexes do
  use Ecto.Migration

  def change do
    # Transactions: fast date-range queries and merchant search
    create_if_not_exists index(:transactions, [:date], name: :transactions_date_index)
    create_if_not_exists index(:transactions, [:merchant_name], name: :transactions_merchant_name_index)
    create_if_not_exists index(:transactions, [:account_id, :date], name: :transactions_account_date_index)
    create_if_not_exists index(:transactions, [:category_id], name: :transactions_category_id_index)

    # Holdings: fast account+symbol lookup
    create_if_not_exists index(:holdings, [:account_id, :symbol], name: :holdings_account_symbol_index)
    create_if_not_exists index(:holdings, [:price_as_of], name: :holdings_price_as_of_index)

    # Sync logs: fast institution status queries
    create_if_not_exists index(:sync_logs, [:institution_id, :status], name: :sync_logs_institution_status_index)
    create_if_not_exists index(:sync_logs, [:completed_at], name: :sync_logs_completed_at_index)

    # Budget months: fast month/year lookups
    create_if_not_exists index(:budget_months, [:month, :year], name: :budget_months_month_year_index)
  end
end
