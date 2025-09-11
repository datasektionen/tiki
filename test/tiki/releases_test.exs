defmodule Tiki.ReleasesTest do
  use Tiki.DataCase

  alias Tiki.Releases

  describe "releases" do
    alias Tiki.Releases.Release

    import Tiki.ReleasesFixtures

    @invalid_attrs %{name: nil, name_sv: nil, starts_at: nil, ends_at: nil}

    test "list_releases/0 returns all releases" do
      release = release_fixture()
      assert Releases.list_releases() == [release]
    end

    test "get_release!/1 returns the release with given id" do
      release = release_fixture()
      assert Releases.get_release!(release.id) == release
    end

    test "create_release/1 with valid data creates a release" do
      valid_attrs = %{name: "some name", name_sv: "some name_sv", starts_at: ~U[2025-09-10 13:05:00Z], ends_at: ~U[2025-09-10 13:05:00Z]}

      assert {:ok, %Release{} = release} = Releases.create_release(valid_attrs)
      assert release.name == "some name"
      assert release.name_sv == "some name_sv"
      assert release.starts_at == ~U[2025-09-10 13:05:00Z]
      assert release.ends_at == ~U[2025-09-10 13:05:00Z]
    end

    test "create_release/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Releases.create_release(@invalid_attrs)
    end

    test "update_release/2 with valid data updates the release" do
      release = release_fixture()
      update_attrs = %{name: "some updated name", name_sv: "some updated name_sv", starts_at: ~U[2025-09-11 13:05:00Z], ends_at: ~U[2025-09-11 13:05:00Z]}

      assert {:ok, %Release{} = release} = Releases.update_release(release, update_attrs)
      assert release.name == "some updated name"
      assert release.name_sv == "some updated name_sv"
      assert release.starts_at == ~U[2025-09-11 13:05:00Z]
      assert release.ends_at == ~U[2025-09-11 13:05:00Z]
    end

    test "update_release/2 with invalid data returns error changeset" do
      release = release_fixture()
      assert {:error, %Ecto.Changeset{}} = Releases.update_release(release, @invalid_attrs)
      assert release == Releases.get_release!(release.id)
    end

    test "delete_release/1 deletes the release" do
      release = release_fixture()
      assert {:ok, %Release{}} = Releases.delete_release(release)
      assert_raise Ecto.NoResultsError, fn -> Releases.get_release!(release.id) end
    end

    test "change_release/1 returns a release changeset" do
      release = release_fixture()
      assert %Ecto.Changeset{} = Releases.change_release(release)
    end
  end
end
