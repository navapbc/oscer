# Technical foundation

## 🧑‍🎨 Frontend

### 🇺🇸 USWDS

The frontend utilizes the [U.S. Web Design System (USWDS)](https://designsystem.digital.gov/) for styling and common components.

To reference USWDS assets, use Rails asset helpers like:

```erb
<%= image_tag "@uswds/uswds/dist/img/usa-icons/close.svg", alt: "Close" %>
<!-- or -->
<img src="<%= asset_path('@uswds/uswds/dist/img/usa-icons/close.svg') %>" alt="Close" />
```

### 🌎 Internationalization (i18n)

The app uses [Rails' built-in i18n support](https://guides.rubyonrails.org/i18n.html). Locale strings are located in `/<APP_NAME>/config/locales`.

Refer to the [Internationalization doc](./internationalization.md) for more details and conventions.

## ⚙️ Backend

### 💽 Database

Postgresql is used for the database.

#### Commands

- Run migrations: `make db-migrate`
- Seed the database: `make db-seed`
- Reset the database: `make db-reset`
  - This will drop the database, recreate the schema based on `db/schema.rb` (not the migrations!), and seed the database
- Access the database console: `make db-console`

#### UUIDs

We have are using [UUIDs for primary keys](https://guides.rubyonrails.org/active_record_postgresql.html#uuid-primary-keys) instead of autoincrementing integers. This has a few implications to beware of:

- ⚠️ Using ActiveRecord functions like `Foo.first` and `Foo.last` have unreliable results
- Generating new models or scaffolds requires passing the `--primary-key-type=uuid` flag. For instance, `make rails-generate GENERATE_COMMAND="model Foo --primary-key-type=uuid"`

#### Enums

⚠️ Important! Enum order cannot be changed.
From https://api.rubyonrails.org/v7.1.3.2/classes/ActiveRecord/Enum.html:

> ... once a value is added to the enum array, its position in the array must be
> maintained, and new values should only be added to the end of the array. To remove
> unused values, the explicit hash syntax should be used.

- Use explicit hashes that map the enum symbol to an integer, instead of implicit arrays. For example: `{ approved: 0, denied: 1}` instead of `[:approved, :denied]`.

### 📫 Notifications

The app uses [Action Mailer](https://guides.rubyonrails.org/action_mailer_basics.html) for sending email notifications. During local development, it uses `letter_opener` to open emails in the browser instead of sending them.

To preview email views in the browser, visit: `/rails/mailers`

To test AWS SES email sending locally:

1. Set the "AWS services" environment variables in your `.env` file.
1. Add an `SES_EMAIL` environment variable to a verified sending identity.
1. Restart the server.

### 🎭 Authentication

The app provides a service and configuration for authentication with AWS Cognito.

Refer to the [Auth doc](./auth.md) for more details and conventions.

## 🔄 Continuous integration

### 🧪 Unit testing

[RSpec](https://rspec.info/) is used for testing. [Capybara](https://www.rubydoc.info/gems/capybara/Capybara/RSpecMatchers) matchers are available.

Run tests with:

```sh
make test
```

Pass additional arguments to `rspec` with `args`:

```sh
make test args="spec/path/to/specific_test.rb"
```

### 🧹 Linting

[Rubocop](https://rubocop.org/) is used for linting.

Run linting with auto-fixing with:

```sh
make lint
```

## ℹ️ Developer norms, tooling, and tips

### 🤖 Norms

Use the rails generator when creating new models, migrations, etc. It does most of the heavy lifting for you.

To create a full scaffold of controller, views, model, database migration:

```sh
make rails-generate GENERATE_COMMAND="scaffold Foo --primary-key-type=uuid"
```

To create a database migration:

```sh
make rails-generate GENERATE_COMMAND="migration AddColumnToTable"
```

To create a model:

```sh
make rails-generate GENERATE_COMMAND="model Foo --primary-key-type=uuid"
```

### 🐛 Debugging

Rails has some useful [built-in debugging tools](https://guides.rubyonrails.org/debugging_rails_applications.html). Here are a few different options:

- Start the [rails console](https://guides.rubyonrails.org/command_line.html#bin-rails-console): `make rails-console`
- Run a console in the browser:
  - Add `<% console %>` to an `.erb` file and an interactive console, similar to the rails console, will appear in the bottom half of your browser window.
  - Note: If the console doesn't appear when running in a docker container, check to see if your IP address is added to the permissions list in `development.rb` (`/<APP_NAME>/config/environments/development.rb`) in `config.web_console.permissions`. The list is currently set to allow most internal IPs. You would also see an error in your terminal that looks something like: `Cannot render console from <your.IP.address.here>! Allowed networks: 127.0.0.0/127.255.255.255, ::1`
- Run the debugger:
  - Add a `debugger` line and the rails server will pause and start the debugger
  - If you're running the app natively, such as with `make start-native`:
    - You must connect to the debugger from another terminal session because of our `Procfile.dev` (`/<APP_NAME>/Procfile.dev`) configuration.
    - From another terminal tab, run `rdbg -A`.
    - If you have multiple Rails applications with debuggers running, you'll have to specify the port to attach the debugger to. For more information, see the [Rails debug gem documentation](https://github.com/ruby/debug?tab=readme-ov-file#remote-debugging).
  - If you're running the app in a container, such as with `make start-container`:
    - `rdbg` in the terminal on your host machine will not be able to see the port in the container to connect to the debugger.
    - Instead, run `rdbg` inside the container: `docker compose exec <APP_NAME> rdbg -A`, where `<APP_NAME>` is the name of the service in `docker compose`
