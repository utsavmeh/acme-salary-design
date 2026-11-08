Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  scope "/api" do
    get "me", to: "me#show"

    resources :employees, only: %i[index show create update] do
      resources :assignments, only: :create
      resources :salary_records, only: %i[index create]
    end
    post "salary_records/:id/correct", to: "salary_records#correct"
  end
end
