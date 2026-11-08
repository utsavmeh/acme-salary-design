Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  scope "/api" do
    get "me", to: "me#show"
    resources :exchange_rates, only: %i[index create]
    get "reports/:name", to: "reports#show"
    get "audit_events/verify", to: "audit_events#verify"
    get "audit_events", to: "audit_events#index"

    get "employees/export", to: "employee_exports#show"
    resources :employees, only: %i[index show create update] do
      resources :assignments, only: :create
      resources :salary_records, only: %i[index create]
    end
    post "salary_records/:id/correct", to: "salary_records#correct"
  end
end
