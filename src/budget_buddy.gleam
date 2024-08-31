import backend/account.{AccountID}
import backend/budget.{init_budget, ready_to_assign}
import gleam/int
import gleam/io

pub fn main() {
  let my_budget =
    init_budget()
    |> budget.add_account(name: "my account", description: "holds all my money")
    |> budget.add_account(
      name: "madie's account",
      description: "holds all of madie's money",
    )
    |> budget.transfer_funds(
      envelope_id: ready_to_assign.envelope_id,
      from: AccountID(1),
      to: AccountID(0),
      amount: 1000,
    )
    |> budget.add_transaction(
      account_id: AccountID(0),
      date: 0,
      to: "PAYCHECK",
      envelope_id: ready_to_assign.envelope_id,
      description: "IT'S PAYDAY RAH",
      amount: 100,
    )
  io.println(budget.to_string(my_budget))
  io.println(
    int.to_string(budget.get_envelope_funding(
      my_budget,
      ready_to_assign.envelope_id,
    )),
  )
}
