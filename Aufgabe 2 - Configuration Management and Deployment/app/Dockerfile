# Use an official Python image
FROM python:3.11-slim

# Install curl
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy only what's needed
COPY api.py .

# Install dependencies
RUN pip install flask

# Expose the Flask app port
EXPOSE 5000

# Run the app
CMD ["python", "api.py"]
