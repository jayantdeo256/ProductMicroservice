# Product Microservice

A .NET 8 microservice for product management with PostgreSQL.

## Features

- RESTful API for product management
- PostgreSQL database integration
- Docker support
- Swagger/OpenAPI documentation
- Health checks
- Ready for Kubernetes deployment

## Technology Stack

- .NET 8
- Entity Framework Core
- PostgreSQL
- Docker & Docker Compose
- ASP.NET Core Web API

## Prerequisites

- .NET 8 SDK
- Docker and Docker Compose
- Git

## Quick Start

### Option 1: Run with Docker Compose (Recommended)

```bash
# Clone the repository
git clone https://github.com/your-username/ProductMicroservice.git
cd ProductMicroservice

# Start PostgreSQL and the application
docker-compose up -d

# The API will be available at:
# - Swagger UI: https://localhost:7000/swagger
# - Health check: https://localhost:7000/health

### Option 2: Run Locally

```bash
# Clone the repository
git clone https://github.com/your-username/ProductMicroservice.git
cd ProductMicroservice

# Start PostgreSQL only with Docker
docker-compose up -d postgres

# Build and run the application
dotnet restore
dotnet build
cd ProductService.API
dotnet run
```

## Project Structure

```text
ProductMicroservice/
├── ProductService.API/          # Web API project (Controllers, DTOs, Program.cs)
├── ProductService.Core/         # Domain models and interfaces
├── ProductService.Infrastructure/ # Data access and repositories
├── .github/workflows/           # CI/CD pipelines
├── docker-compose.yml           # Docker configuration
├── README.md                    # This file
└── ProductMicroservice.sln      # Solution file
```

## API Endpoints

## API Endpoints

| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/products` | Get all products |
| GET | `/api/products/{id}` | Get product by ID |
| POST | `/api/products` | Create new product |
| PUT | `/api/products/{id}` | Update product |
| DELETE | `/api/products/{id}` | Delete product |
| GET | `/health` | Service health status |

## Example API Usage

### Create a product:

```bash
curl -X POST "https://localhost:7000/api/products" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Sample Product",
    "description": "This is a sample product",
    "price": 29.99,
    "stock": 100
  }'
```

### Get all products:

```bash
curl "https://localhost:7000/api/products"
```

## Database Configuration

The application uses PostgreSQL with the following default configuration:

Host: localhost

Port: 5432

Database: productdb

Username: postgres

Password: password

### Database Connection String
Update the connection string in ProductService.API/appsettings.json if needed:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Host=localhost;Port=5432;Database=productdb;Username=postgres;Password=password;Pooling=true;"
  }
}
```

Docker Configuration
Services
postgres: PostgreSQL 15 database

productservice: .NET 8 API (when using full docker-compose)

Docker Commands
```bash
# Start services
docker-compose up -d

# Stop services
docker-compose down

# View logs
docker-compose logs

# Check service status
docker-compose ps
```

Development
Building the Project
```bash
# Restore dependencies
dotnet restore

# Build solution
dotnet build

# Run tests (if any)
dotnet test
Running in Development Mode
bash
cd ProductService.API
dotnet run --environment=Development
```
## Database Migrations
The application uses EnsureCreatedAsync() to automatically create the database schema. For production, consider using EF Core migrations:

```bash
# Create migration
dotnet ef migrations add InitialCreate --project ProductService.Infrastructure --startup-project ProductService.API

# Apply migration
dotnet ef database update --project ProductService.Infrastructure --startup-project ProductService.API
```

## Health Checks
The service includes a health check endpoint:

URL: GET /health

Response: { "status": "Healthy", "timestamp": "2024-01-01T00:00:00Z" }

Monitoring Ready

This application is prepared for monitoring with:

Prometheus metrics endpoint (to be configured)

Grafana dashboards

Alertmanager integration

Slack notifications

Kubernetes Deployment
The application is Kubernetes-ready with:

Health check endpoints

Environment-based configuration

Docker containerization

Database connection retry logic

Roadmap
✅ Push code to GitHub repository

🔄 Set up monitoring (Prometheus, Grafana, Alertmanager)

🔄 Integrate with Slack for alerts

🔄 Migrate to Kubernetes with GitOps (ArgoCD)

## Troubleshooting
Common Issues
Docker permission denied:

```bash
sudo usermod -aG docker $USER
newgrp docker
```
Port 5432 already in use:

```bash
sudo lsof -i :5432
# Kill the process or change port in docker-compose.yml
```
Database connection issues:

Check if PostgreSQL container is running: docker ps

Verify credentials in appsettings.json

Check container logs: docker logs postgresql

## Logs
View application logs:

```bash
docker-compose logs productservice
```

View database logs:

```bash
docker-compose logs postgres
```

## Contributing
Fork the repository

Create a feature branch: git checkout -b feature/new-feature

Commit changes: git commit -am 'Add new feature'

Push to branch: git push origin feature/new-feature

Submit a pull request

## License
This project is licensed under the MIT License.

## Support
For support, please open an issue on GitHub or contact the development team.

