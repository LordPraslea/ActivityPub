defmodule ActivityPubWeb.PublisherTest do
  alias ActivityPub.Actor
  alias ActivityPubWeb.Publisher
  import ActivityPub.Factory
  import Tesla.Mock
  use ActivityPub.DataCase

  setup do
    mock(fn
      %{method: :post} -> %Tesla.Env{status: 200}
    end)

    :ok
  end

  test "it publishes an activity" do
    note_actor = local_actor()
    {:ok, note_actor} = Actor.get_by_username(note_actor.username)
    recipient_actor = actor()

    note =
      insert(:note, %{
        actor: note_actor,
        data: %{
          "to" => [recipient_actor.ap_id, "https://www.w3.org/ns/activitystreams#Public"],
          "cc" => note_actor.data["followers"]
        }
      })

    activity = insert(:note_activity, %{note: note})
    {:ok, actor} = Actor.get_by_ap_id(activity.data["actor"])

    assert :ok == Publisher.publish(actor, activity)
    assert %{success: 1, failure: 0} = Oban.drain_queue(queue: :federator_outgoing)
  end

  test "it adds mothership recipient if the env is set" do
    System.put_env("CONNECT_WITH_MOTHERSHIP", "true")
    note_actor = local_actor()
    {:ok, note_actor} = Actor.get_by_username(note_actor.username)
    recipient_actor = actor()

    note =
      insert(:note, %{
        actor: note_actor,
        data: %{
          "to" => [recipient_actor.ap_id, "https://www.w3.org/ns/activitystreams#Public"],
          "cc" => note_actor.data["followers"]
        }
      })

    activity = insert(:note_activity, %{note: note})
    {:ok, actor} = Actor.get_by_ap_id(activity.data["actor"])

    assert :ok == Publisher.publish(actor, activity)
    assert %{success: 2, failure: 0} = Oban.drain_queue(queue: :federator_outgoing)
    System.put_env("CONNECT_WITH_MOTHERSHIP", "false")
  end

  @tag :skip
  test "it publishes to followers" do
    community = Faking.fake_user!() |> Faking.fake_community!()
    actor_1 = actor()
    actor_2 = actor()
    {:ok, ap_community} = ActivityPub.Actor.get_by_local_id(community.id)

    ActivityPub.follow(actor_1, ap_community, nil, false)
    ActivityPub.follow(actor_2, ap_community, nil, false)
    Oban.drain_queue(queue: :ap_incoming)

    activity =
      insert(:note_activity, %{
        actor: ap_community,
        data_attrs: %{"cc" => [ap_community.data["followers"]]}
      })

    assert :ok == Publisher.publish(ap_community, activity)
    assert %{failure: 0, success: 2} = Oban.drain_queue(:federator_outgoing)
  end
end
