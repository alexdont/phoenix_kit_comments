defmodule PhoenixKitComments.Integration.ReactionsTest do
  @moduledoc """
  The reaction path carried three defects at once and had zero coverage,
  because the project had no database configured at all. These are the tests
  that would have caught them.
  """
  use PhoenixKitComments.DataCase, async: false

  alias PhoenixKitComments.CommentLike
  alias PhoenixKitComments.Test.Repo

  setup do
    user = user_fixture()
    other = user_fixture()
    {:ok, user: user, other: other, comment: comment_fixture(user)}
  end

  describe "counters follow the rows" do
    test "a like counts once", %{user: user, comment: comment} do
      assert {:ok, :liked} = PhoenixKitComments.like_comment(comment.uuid, user.uuid)
      assert Repo.get(PhoenixKitComments.Comment, comment.uuid).like_count == 1
    end

    test "unlike removes N rows and decrements by N, not by one", %{
      user: user,
      comment: comment
    } do
      {:ok, :liked} = PhoenixKitComments.like_comment(comment.uuid, user.uuid)

      # Duplicates are reachable: there is no unique index on
      # (comment_uuid, user_uuid) — it was dropped during the uuid-FK
      # migration and never recreated, which is why the schemas' own
      # `unique_constraint` is dead code. Insert one directly to stand in
      # for the concurrent double-click the row lock now prevents.
      Repo.insert!(%CommentLike{comment_uuid: comment.uuid, user_uuid: user.uuid})

      from(c in PhoenixKitComments.Comment, where: c.uuid == ^comment.uuid)
      |> Repo.update_all(inc: [like_count: 1])

      assert Repo.get(PhoenixKitComments.Comment, comment.uuid).like_count == 2

      assert {:ok, :unliked} = PhoenixKitComments.unlike_comment(comment.uuid, user.uuid)

      # Decrementing by one here left the count stuck above the truth with
      # no user-reachable way to bring it down.
      assert Repo.get(PhoenixKitComments.Comment, comment.uuid).like_count == 0
      assert Repo.aggregate(CommentLike, :count) == 0
    end

    test "a like replaces a dislike, and both counters move", %{user: user, comment: comment} do
      {:ok, :disliked} = PhoenixKitComments.dislike_comment(comment.uuid, user.uuid)
      {:ok, :liked} = PhoenixKitComments.like_comment(comment.uuid, user.uuid)

      reloaded = Repo.get(PhoenixKitComments.Comment, comment.uuid)
      assert reloaded.like_count == 1
      assert reloaded.dislike_count == 0
    end

    test "the counter never goes negative", %{user: user, comment: comment} do
      assert {:error, :not_found} = PhoenixKitComments.unlike_comment(comment.uuid, user.uuid)
      assert Repo.get(PhoenixKitComments.Comment, comment.uuid).like_count == 0
    end
  end

  describe "a repeat click is still a write" do
    test "liking twice keeps one row and one count", %{user: user, comment: comment} do
      {:ok, :liked} = PhoenixKitComments.like_comment(comment.uuid, user.uuid)
      assert {:ok, :already_liked} = PhoenixKitComments.like_comment(comment.uuid, user.uuid)

      assert Repo.get(PhoenixKitComments.Comment, comment.uuid).like_count == 1
      assert Repo.aggregate(CommentLike, :count) == 1
    end

    test "a repeat like that clears a dislike broadcasts the change", %{
      user: user,
      comment: comment
    } do
      {:ok, :liked} = PhoenixKitComments.like_comment(comment.uuid, user.uuid)
      PhoenixKitComments.subscribe(comment.resource_type, comment.resource_uuid)

      # Someone dislikes from elsewhere, then the original liker clicks like
      # again: `:already_liked`, but the dislike removal COMMITTED. This used
      # to fall through `after_reaction/3`'s no-op clause, leaving every
      # other subscriber showing a count that no longer existed.
      {:ok, :disliked} = PhoenixKitComments.dislike_comment(comment.uuid, user.uuid)
      assert_receive {:comments_updated, %{action: :reaction}}

      assert {:ok, :liked} = PhoenixKitComments.like_comment(comment.uuid, user.uuid)
      assert_receive {:comments_updated, %{action: :reaction}}
    end
  end

  describe "reactions are per user" do
    test "two users each count once", %{user: user, other: other, comment: comment} do
      {:ok, :liked} = PhoenixKitComments.like_comment(comment.uuid, user.uuid)
      {:ok, :liked} = PhoenixKitComments.like_comment(comment.uuid, other.uuid)

      assert Repo.get(PhoenixKitComments.Comment, comment.uuid).like_count == 2
      assert PhoenixKitComments.comment_liked_by?(comment.uuid, user.uuid)
      assert PhoenixKitComments.comment_liked_by?(comment.uuid, other.uuid)
    end

    test "one user's unlike leaves the other's like alone", %{
      user: user,
      other: other,
      comment: comment
    } do
      {:ok, :liked} = PhoenixKitComments.like_comment(comment.uuid, user.uuid)
      {:ok, :liked} = PhoenixKitComments.like_comment(comment.uuid, other.uuid)
      {:ok, :unliked} = PhoenixKitComments.unlike_comment(comment.uuid, user.uuid)

      assert Repo.get(PhoenixKitComments.Comment, comment.uuid).like_count == 1
      refute PhoenixKitComments.comment_liked_by?(comment.uuid, user.uuid)
      assert PhoenixKitComments.comment_liked_by?(comment.uuid, other.uuid)
    end
  end
end
