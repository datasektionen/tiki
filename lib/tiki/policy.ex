defmodule Tiki.Policy do
  use LetMe.Policy

  object :tiki do
    action :admin do
      allow pls: "admin"
    end

    action :manage do
      allow pls: "admin"
      allow any_team_role: :admin
      allow any_team_role: :member
    end
  end

  object :event do
    action :manage do
      allow pls: "admin"
      allow team_role: :admin
      allow team_role: :member
    end

    action :create do
      allow pls: "admin"
      allow team_role: :admin
    end
  end

  object :team do
    action :admin do
      allow pls: "admin"
    end

    action :create do
      allow pls: "admin"
    end

    action :read do
      allow pls: "admin"
      allow team_role: :admin
      allow team_role: :member
    end

    action :update do
      allow pls: "admin"
      allow team_role: :admin
    end
  end
end
