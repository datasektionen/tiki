defmodule Tiki.Policy do
  use LetMe.Policy

  object :tiki do
    action :admin do
      allow hive: "admin"
    end

    action :manage do
      allow hive: "admin"
      allow any_team_role: :admin
      allow any_team_role: :member
    end
  end

  object :event do
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

    action :read do
      allow hive: "admin"
      allow team_role: :admin
      allow team_role: :member
    end

    action :update do
      allow hive: "admin"
      allow team_role: :admin
    end
  end
end
