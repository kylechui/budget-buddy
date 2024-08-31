import backend/account.{type Account, type AccountID, Account, AccountID}
import backend/envelope.{type Envelope, type EnvelopeID, Envelope, EnvelopeID}
import backend/transaction.{
  type Transaction, type TransactionID, Transaction, TransactionID,
}
import gleam/bool
import gleam/dynamic.{field, int, list, string}
import gleam/int
import gleam/io
import gleam/json.{type Json}
import gleam/list
import gleam/result
import gleam/string
import simplifile as file

pub const ready_to_assign: Envelope = Envelope(
  envelope_id: EnvelopeID(0),
  name: "Ready to Assign",
  funding_goal: 0,
)

// TODO: Use env vars to figure out where to put this config file
const database_path: String = "/home/kylec/.local/share/budget_buddy/balances.json"

const default_budget: Budget = Budget(
  accounts: [],
  envelopes: [ready_to_assign],
  transactions: [],
)

/// IDs for each transaction are unique, monotonic decreasing
pub type Budget {
  Budget(
    accounts: List(Account),
    envelopes: List(Envelope),
    transactions: List(Transaction),
  )
}

/// Updates the database using the current state of the budget
/// Side effect: Writes to the filesystem
fn update_database(budget: Budget) -> Nil {
  let budget_str: String = budget |> to_json |> json.to_string
  let _ = file.write(to: database_path, contents: budget_str)
  Nil
}

fn require_database_file(continue) -> Budget {
  case file.is_file(database_path) {
    Ok(True) -> continue()
    Ok(False) -> {
      update_database(default_budget)
      default_budget
    }
    Error(_) -> panic as { "Can't read file: " <> database_path }
  }
}

pub fn init_budget() -> Budget {
  use <- require_database_file
  let str: String = case file.read(from: database_path) {
    Ok(contents) -> contents
    Error(_) -> panic as { "Error reading from file: " <> database_path }
  }
  // TODO: This is literally just deserialization from JSON; make it more apparent
  let account_id_decoder = fn(dynamic) {
    use account_int <- result.try(int(dynamic))
    Ok(AccountID(account_int))
  }
  dynamic.decode1(AccountID, field("id", of: int))
  let account_decoder =
    dynamic.decode3(
      Account,
      field("account_id", of: account_id_decoder),
      field("name", of: string),
      field("description", of: string),
    )
  let envelope_id_decoder = fn(dynamic) {
    use envelope_int <- result.try(int(dynamic))
    Ok(EnvelopeID(envelope_int))
  }
  let envelope_decoder =
    dynamic.decode3(
      Envelope,
      field("envelope_id", of: envelope_id_decoder),
      field("name", of: string),
      field("funding_goal", of: int),
    )
  let transaction_id_decoder = fn(dynamic) {
    use transaction_int <- result.try(int(dynamic))
    Ok(TransactionID(transaction_int))
  }
  let transaction_decoder =
    dynamic.decode7(
      Transaction,
      field("transaction_id", of: transaction_id_decoder),
      field("account_id", of: account_id_decoder),
      field("date", of: int),
      field("payee", of: string),
      field("envelope_id", of: envelope_id_decoder),
      field("description", of: string),
      field("delta", of: int),
    )
  let budget_decoder =
    dynamic.decode3(
      Budget,
      field("accounts", of: list(account_decoder)),
      field("envelopes", of: list(envelope_decoder)),
      field("transactions", of: list(transaction_decoder)),
    )
  case json.decode(from: str, using: budget_decoder) {
    Ok(budget) -> budget
    Error(_) -> panic as { "Error in configuration file: " <> database_path }
  }
}

pub fn get_account(
  budget: Budget,
  account_id: AccountID,
) -> Result(Account, Nil) {
  list.find(budget.accounts, fn(account) { account.account_id == account_id })
}

pub fn get_account_balance(budget: Budget, account_id: AccountID) -> Int {
  budget.transactions
  |> list.filter(fn(transaction) { transaction.account_id == account_id })
  |> list.map(fn(transaction) { transaction.delta })
  |> int.sum
}

pub fn get_envelope_funding(budget: Budget, envelope_id: EnvelopeID) -> Int {
  budget.transactions
  |> list.filter(fn(transaction) { transaction.envelope_id == envelope_id })
  |> list.map(fn(transaction) { transaction.delta })
  |> list.filter(fn(delta) { delta > 0 })
  |> int.sum
}

fn next_transaction_id(budget: Budget) -> TransactionID {
  case budget.transactions {
    [] -> TransactionID(0)
    [transaction, ..] -> {
      let TransactionID(id) = transaction.transaction_id
      TransactionID(id + 1)
    }
  }
}

pub fn add_transaction(
  budget: Budget,
  account_id account_id: AccountID,
  date date: Int,
  to payee: String,
  envelope_id envelope_id: EnvelopeID,
  description description: String,
  amount delta: Int,
) -> Budget {
  let new_transaction =
    Transaction(
      transaction_id: next_transaction_id(budget),
      date: date,
      account_id: account_id,
      payee: payee,
      envelope_id: envelope_id,
      description: description,
      delta: delta,
    )
  let new_budget =
    Budget(..budget, transactions: [new_transaction, ..budget.transactions])
  update_database(new_budget)
  new_budget
}

// TODO
// pub fn delete_transaction(budget: Budget, id id: Int) -> Budget {
//   let new_transactions =
//     budget.transactions
//     |> list.filter(fn(transaction) { transaction.id != id })
//   Budget(..budget, transactions: new_transactions)
// }

/// Transfers funds within one envelope from one account to another
pub fn transfer_funds(
  budget: Budget,
  envelope_id envelope_id: EnvelopeID,
  from payer_id: AccountID,
  to payee_id: AccountID,
  amount amount: Int,
) -> Budget {
  case get_account(budget, payer_id), get_account(budget, payee_id) {
    Error(Nil), _ -> budget
    _, Error(Nil) -> budget
    Ok(payer), Ok(payee) -> {
      budget
      |> add_transaction(
        account_id: payer_id,
        date: 0,
        to: payee.name,
        envelope_id: envelope_id,
        description: "Transfer to " <> payee.name,
        amount: amount,
      )
      |> add_transaction(
        account_id: payee_id,
        date: 0,
        to: payer.name,
        envelope_id: envelope_id,
        description: "Transfer from " <> payer.name,
        amount: -amount,
      )
    }
  }
}

fn next_account_id(budget: Budget) -> AccountID {
  case budget.accounts {
    [] -> AccountID(0)
    [account, ..] -> {
      let AccountID(id) = account.account_id
      AccountID(id + 1)
    }
  }
}

pub fn add_account(
  budget: Budget,
  name name: String,
  description description: String,
) -> Budget {
  let new_account: Account =
    Account(
      account_id: next_account_id(budget),
      name: name,
      description: description,
    )
  Budget(..budget, accounts: [new_account, ..budget.accounts])
}

pub fn to_json(budget: Budget) -> Json {
  json.object([
    #("accounts", json.array(budget.accounts, of: account.to_json)),
    #("envelopes", json.array(budget.envelopes, of: envelope.to_json)),
    #("transactions", json.array(budget.transactions, of: transaction.to_json)),
  ])
}

pub fn to_string(budget: Budget) -> String {
  budget |> to_json |> json.to_string
}
