import gleam/json.{type Json}

pub type EnvelopeID {
  EnvelopeID(Int)
}

pub type Envelope {
  Envelope(envelope_id: EnvelopeID, name: String, funding_goal: Int)
}

pub fn to_json(envelope: Envelope) -> Json {
  json.object([
    #("envelope_id", {
      let EnvelopeID(id) = envelope.envelope_id
      json.int(id)
    }),
    #("name", json.string(envelope.name)),
    #("funding_goal", json.int(envelope.funding_goal)),
  ])
}

pub fn to_string(envelope: Envelope) -> String {
  envelope |> to_json |> json.to_string
}
