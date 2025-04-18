# Use an official Python runtime as a parent image
FROM python:3.11-slim

# Set the working directory in the container
WORKDIR /app

# Copy the requirements file into the container at /app
COPY requirements.txt .

# Install any needed packages specified in requirements.txt
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy the current directory contents into the container at /app
# Assuming the app source code will be mounted or added later if needed
# For now, we only need the installed packages

# Make port 8001 available to the world outside this container
EXPOSE 8001

# Define environment variable
ENV NAME Crawl4AI

# Run uvicorn when the container launches using python -m
CMD ["python", "-m", "uvicorn", "crawl4ai.app:app", "--host", "0.0.0.0", "--port", "8001"] 