import gleam/json.{type Json}

pub type AccountID {
  AccountID(Int)
}

pub type Account {
  Account(account_id: AccountID, name: String, description: String)
}

pub fn to_json(account: Account) -> Json {
  json.object([
    #("account_id", {
      let AccountID(id) = account.account_id
      json.int(id)
    }),
    #("name", json.string(account.name)),
    #("description", json.string(account.description)),
  ])
}

pub fn to_string(account: Account) -> String {
  account |> to_json |> json.to_string
}
