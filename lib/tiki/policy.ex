defmodule Tiki.Policy do
  use LetMe.Policy

  object :tiki do
    action :admin do
      allow role: :admin
    end
  end

  object :team do
    action :create do
      true
    end

    action :update do
      true
    end

    action :delete do
      true
    end
  end
end
