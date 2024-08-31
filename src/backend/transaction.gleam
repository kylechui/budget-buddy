import backend/account.{type AccountID, AccountID}
import backend/envelope.{type EnvelopeID, EnvelopeID}
import gleam/int
import gleam/json.{type Json}
import gleam/string

pub type TransactionID {
  TransactionID(Int)
}

pub type Transaction {
  Transaction(
    transaction_id: TransactionID,
    account_id: AccountID,
    // TODO: Use an actual date type
    date: Int,
    payee: String,
    envelope_id: EnvelopeID,
    description: String,
    delta: Int,
  )
}

pub fn change_envelope(
  transaction: Transaction,
  to envelope_id: EnvelopeID,
) -> Transaction {
  Transaction(..transaction, envelope_id: envelope_id)
}

pub fn to_json(transaction: Transaction) -> Json {
  json.object([
    #("transaction_id", {
      let TransactionID(id) = transaction.transaction_id
      json.int(id)
    }),
    #("account_id", {
      let AccountID(id) = transaction.account_id
      json.int(id)
    }),
    #("date", json.int(transaction.date)),
    #("payee", json.string(transaction.payee)),
    #("envelope_id", {
      let EnvelopeID(id) = transaction.envelope_id
      json.int(id)
    }),
    #("description", json.string(transaction.description)),
    #("delta", json.int(transaction.delta)),
  ])
}

pub fn to_string(transaction: Transaction) -> String {
  transaction |> to_json |> json.to_string
}
