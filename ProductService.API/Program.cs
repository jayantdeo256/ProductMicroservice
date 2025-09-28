using Microsoft.EntityFrameworkCore;
using ProductService.Infrastructure.Data;
using ProductService.Infrastructure;
using Prometheus;

var builder = WebApplication.CreateBuilder(args);

// Add services
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddHealthChecks().ForwardToPrometheus();
builder.Services.AddInfrastructure(builder.Configuration);

var app = builder.Build();

// Configure pipeline
app.UseSwagger();
app.UseSwaggerUI();

// ✅ METRICS MIDDLEWARE - SIMPLE AND CORRECT
app.UseRouting();
app.UseHttpMetrics();
app.MapMetrics();  // This exposes /metrics

app.MapControllers();
app.MapHealthChecks("/health");

app.MapGet("/", () => "Product Service API - Metrics: /metrics");

// Database initialization
try
{
    using var scope = app.Services.CreateScope();
    var context = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
    context.Database.EnsureCreated();
    Console.WriteLine("Database initialized");
}
catch (Exception ex)
{
    Console.WriteLine($"Database error: {ex.Message}");
}

Console.WriteLine("Application starting on port 8080...");
app.Run();
