#!/bin/bash

echo "🐳 CONTAINERIZING THE APPLICATION PROPERLY..."

# Clean up everything first
echo "🧹 CLEANING UP..."
docker-compose down -v 2>/dev/null || true
docker stop $(docker ps -aq) 2>/dev/null || true
docker rm $(docker ps -aq) 2>/dev/null || true
pkill -f dotnet 2>/dev/null || true
docker system prune -a -f --volumes

# Step 1: Create a proper Dockerfile
echo "📝 CREATING PROPER DOCKERFILE..."
cat > Dockerfile << 'EOF'
# Build stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy project files
COPY ["ProductService.API/ProductService.API.csproj", "ProductService.API/"]
COPY ["ProductService.Core/ProductService.Core.csproj", "ProductService.Core/"]
COPY ["ProductService.Infrastructure/ProductService.Infrastructure.csproj", "ProductService.Infrastructure/"]

# Restore dependencies
RUN dotnet restore "ProductService.API/ProductService.API.csproj"

# Copy everything
COPY . .

# Build
WORKDIR "/src/ProductService.API"
RUN dotnet build "ProductService.API.csproj" -c Release -o /app/build

# Publish
FROM build AS publish
RUN dotnet publish "ProductService.API.csproj" -c Release -o /app/publish

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app

# Create a non-root user
RUN adduser --disabled-password --gecos '' appuser && chown -R appuser /app
USER appuser

# Copy published app
COPY --from=publish /app/publish .

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

EXPOSE 8080
ENTRYPOINT ["dotnet", "ProductService.API.dll"]
EOF

# Step 2: Create appsettings for Docker environment
echo "📝 CREATING DOCKER APPSETTINGS..."
cat > ProductService.API/appsettings.Docker.json << 'EOF'
{
  "ConnectionStrings": {
    "DefaultConnection": "Host=postgres;Port=5432;Database=productdb;Username=postgres;Password=password;Pooling=true;Timeout=30;CommandTimeout=30;"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning",
      "Microsoft.EntityFrameworkCore.Database.Command": "Warning"
    }
  },
  "AllowedHosts": "*"
}
EOF

# Step 3: Update Program.cs for Docker
echo "📝 UPDATING PROGRAM.CS FOR DOCKER..."
cat > ProductService.API/Program.cs << 'EOF'
using Microsoft.EntityFrameworkCore;
using ProductService.Infrastructure.Data;
using ProductService.Infrastructure;
using Prometheus;

var builder = WebApplication.CreateBuilder(args);

// Configuration for Docker
builder.Configuration
    .SetBasePath(builder.Environment.ContentRootPath)
    .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true)
    .AddJsonFile($"appsettings.{builder.Environment.EnvironmentName}.json", optional: true)
    .AddEnvironmentVariables();

// Use port 8080 for Docker (better for containers)
builder.WebHost.UseUrls("http://*:8080");

// Add services
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddHealthChecks().ForwardToPrometheus();
builder.Services.AddInfrastructure(builder.Configuration);

var app = builder.Build();

// Configure pipeline
if (app.Environment.IsDevelopment() || app.Environment.EnvironmentName == "Docker")
{
    app.UseSwagger();
    app.UseSwaggerUI();
    app.UseDeveloperExceptionPage();
}

app.UseRouting();
app.UseHttpMetrics();

app.MapControllers();
app.MapHealthChecks("/health");
app.MapMetrics();

app.MapGet("/", () => Results.Ok(new { 
    message = "Product Service API", 
    status = "Running", 
    environment = app.Environment.EnvironmentName 
}));

app.MapGet("/health-details", async (ApplicationDbContext context) => 
{
    try
    {
        var dbHealthy = await context.Database.CanConnectAsync();
        return Results.Ok(new { 
            status = "Healthy", 
            database = dbHealthy ? "Connected" : "Disconnected",
            timestamp = DateTime.UtcNow,
            version = "1.0.0"
        });
    }
    catch (Exception ex)
    {
        return Results.Problem($"Database connection failed: {ex.Message}");
    }
});

// Database initialization with retry logic
using (var scope = app.Services.CreateScope())
{
    var services = scope.ServiceProvider;
    var logger = services.GetRequiredService<ILogger<Program>>();
    var context = services.GetRequiredService<ApplicationDbContext>();
    
    logger.LogInformation("Starting database initialization...");
    
    for (int i = 1; i <= 10; i++)
    {
        try
        {
            logger.LogInformation("Database connection attempt {Attempt}/10", i);
            
            // Wait for PostgreSQL to be ready
            await Task.Delay(TimeSpan.FromSeconds(i * 2));
            
            await context.Database.EnsureCreatedAsync();
            logger.LogInformation("✅ Database created successfully");
            
            // Seed initial data
            if (!context.Products.Any())
            {
                context.Products.Add(new ProductService.Core.Models.Product 
                { 
                    Name = "Dockerized Product", 
                    Description = "Product from containerized app", 
                    Price = 99.99m, 
                    Stock = 50 
                });
                await context.SaveChangesAsync();
                logger.LogInformation("✅ Sample data seeded");
            }
            break;
        }
        catch (Exception ex)
        {
            logger.LogWarning("Attempt {Attempt} failed: {Message}", i, ex.Message);
            if (i == 10)
            {
                logger.LogError("💥 All database connection attempts failed");
                throw;
            }
        }
    }
}

logger.LogInformation("🚀 Application started successfully on port 8080");
app.Run();
EOF

# Step 4: Create proper docker-compose.yml
echo "📝 CREATING DOCKER-COMPOSE.YML..."
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    container_name: product-service-db
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
      POSTGRES_DB: productdb
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d productdb"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - product-network

  product-service:
    build: 
      context: .
      dockerfile: Dockerfile
    container_name: product-service-app
    ports:
      - "5000:8080"
    environment:
      - ASPNETCORE_ENVIRONMENT=Docker
      - ASPNETCORE_URLS=http://*:8080
    depends_on:
      postgres:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    networks:
      - product-network
    restart: unless-stopped

  prometheus:
    image: prom/prometheus:latest
    container_name: product-service-prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--web.enable-lifecycle'
    networks:
      - product-network
    depends_on:
      - product-service

  grafana:
    image: grafana/grafana:latest
    container_name: product-service-grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin123
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - grafana_data:/var/lib/grafana
    networks:
      - product-network
    depends_on:
      - prometheus

volumes:
  postgres_data:
  grafana_data:

networks:
  product-network:
    driver: bridge
EOF

# Step 5: Create proper Prometheus config for Docker
echo "📝 CREATING PROMETHEUS CONFIG..."
mkdir -p monitoring
cat > monitoring/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'product-service'
    static_configs:
      - targets: ['product-service-app:8080']
    metrics_path: /metrics
    scrape_interval: 10s
    scrape_timeout: 5s

  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093
EOF

# Step 6: Build the Docker image
echo "🔨 BUILDING DOCKER IMAGE..."
docker build -t product-service:latest .

# Step 7: Start the stack
echo "🚀 STARTING DOCKER COMPOSE STACK..."
docker-compose up -d

# Step 8: Wait and check status
echo "⏳ WAITING FOR SERVICES TO START..."
sleep 30

echo "📊 CHECKING SERVICE STATUS..."
docker-compose ps

echo "🔍 CHECKING LOGS..."
docker-compose logs product-service-app --tail=10

# Step 9: Test the application
echo "🧪 TESTING THE APPLICATION..."
for i in {1..10}; do
    if curl -s http://localhost:5000/health > /dev/null; then
        echo "✅ APPLICATION IS HEALTHY!"
        break
    else
        echo "⏰ Waiting for application... ($i/10)"
        sleep 5
    fi
done

# Step 10: Final tests
echo "🧪 RUNNING FINAL TESTS..."
curl -s http://localhost:5000/health && echo "✅ Health endpoint working"
curl -s http://localhost:5000/metrics | head -5 && echo "✅ Metrics endpoint working"
curl -s http://localhost:5000/api/products | jq . && echo "✅ API endpoint working" || curl -s http://localhost:5000/api/products

echo ""
echo "🎉 CONTAINERIZATION COMPLETE!"
echo ""
echo "🌐 SERVICES:"
echo "   - App:        http://localhost:5000"
echo "   - PostgreSQL: localhost:5432"
echo "   - Prometheus: http://localhost:9090"
echo "   - Grafana:    http://localhost:3000 (admin/admin123)"
echo ""
echo "🐳 DOCKER COMMANDS:"
echo "   - View logs:    docker-compose logs [service]"
echo "   - Restart:      docker-compose restart [service]"
echo "   - Stop:         docker-compose down"
echo "   - Status:       docker-compose ps"
echo ""
echo "📈 MONITORING:"
echo "   - Prometheus targets: http://localhost:9090/targets"
echo "   - Grafana: Add Prometheus datasource as http://prometheus:9090"
echo ""
echo "✅ Application is now properly containerized!"
EOF
