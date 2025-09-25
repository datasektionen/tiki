defmodule Tiki.Policy do
  use LetMe.Policy

  object :flags do
    action :admin do
      allow hive: "admin"
    end
  end

  object :tiki do
    action :admin do
      allow hive: "admin"
      allow hive: "audit"
    end

    action :manage do
      allow hive: "admin"
      allow hive: "audit"
      allow any_team_role: :admin
      allow any_team_role: :member
    end
  end

  object :event do
    action :view do
      allow hive: "admin"
      allow hive: "audit"
      allow team_role: :admin
      allow team_role: :member
    end

    action :manage do
      allow hive: "admin"
      allow team_role: :admin
      allow team_role: :member
    end

    action :create do
      allow hive: "admin"
      allow team_role: :admin
    end
  end

  object :team do
    action :admin do
      allow hive: "admin"
    end

    action :create do
      allow hive: "admin"
    end

    action :view_all do
      allow hive: "admin"
      allow hive: "audit"
    end

    action :read do
      allow hive: "admin"
      allow hive: "audit"
      allow team_role: :admin
      allow team_role: :member
    end

    action :update do
      allow hive: "admin"
      allow team_role: :admin
    end

    action :assume_all do
      allow hive: "admin"
      allow hive: "audit"
    end
  end
end
