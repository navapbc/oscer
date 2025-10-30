# Lookbook

Lookbook is a tool for documenting and showcasing your application's components. It allows you to create a living style guide that can be shared with your team and stakeholders. It is particularly useful for frontend developers, designers, and product managers to see the components in action and understand how they can be used.

## Enabling Lookbook

To enable Lookbook in your application, you need to set the `ENABLE_LOOKBOOK` environment variable to `true`. Locally this can be done by adding the following line to your `.env` file:

```env
ENABLE_LOOKBOOK=true
```

If you are using the Nava Platform infrastructure template, you can enable Lookbook in the dev environment by adding the following code to `/infra/<APP_NAME>/app-config/dev.tf`:

```terraform
service_override_extra_environment_variables = {
  ENABLE_LOOKBOOK = "true"
}
```

## Creating Lookbook previews

### Previewing partial components

When creating Lookbook previews for Rails partial components, remember to do the following:

1. Set the layout to `"component_preview"` to avoid rendering the application header and footer.
2. In the render method call, specify the `template:` parameter explicitly, and include the underscore in front of the partial name. At the time of writing, Lookbook does not support rendering with `render "string"` or `render partial: "partial/name"`.

Here's an example of a Lookbook preview that follows these guidelines:

```ruby
class ExamplePreview < Lookbook::Preview
  layout "component_preview"

  def default
    render template: "application/_example", locals: {}
  end
end
```
