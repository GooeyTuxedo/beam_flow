# BeamFlow CMS

BeamFlow is a modern, performant blogging CMS built with Elixir and Phoenix LiveView, focusing on a streamlined user experience, real-time features, and markdown-based content creation.

## Features

- User authentication and authorization with role-based access control
- Content management (posts, pages, media)
- Tagging and categorization
- Real-time comments management
- Markdown editor with live preview
- Media management with image optimization
- RESTful API endpoints
- Comprehensive admin dashboard

## Technology Stack

- Elixir 1.18
- Phoenix 1.7.20
- Ecto 4.6.3
- PostgreSQL 16
- TailwindCSS
- Alpine.js (for client-side interactions)

## Development Environment

BeamFlow uses Docker Compose for local development:

```bash
# Clone the repository
git clone https://github.com/gooeytuxedo/beam_flow.git
cd beam_flow

# Start the development environment
docker compose up -d

# Run migrations
docker compose exec app mix ecto.setup

# Visit the application at http://localhost:4000
```

## Testing

```bash
# Run the test suite
docker compose exec app mix test

# Check code formatting
docker compose exec app mix format --check-formatted

# Run code linting
docker compose exec app mix credo --strict
```

## Contributing

Please see [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.