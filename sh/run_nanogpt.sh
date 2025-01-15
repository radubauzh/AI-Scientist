#!/bin/bash
#SBATCH --partition=use-everything      # Target the partition with newer GPUs
#SBATCH --gres=gpu:1                    # Request 1 GPU, model to be selected dynamically
#SBATCH --time=2:00:00                  # Set a time limit for the job
#SBATCH --mem=16G                       # Set memory limit (e.g., 16 GB)
#SBATCH --cpus-per-task=4               # Allocate 4 CPU cores
#SBATCH --job-name=SetupNanoGPT         # Set a name for the job
#SBATCH --output=/om2/user/raduba/AI-Scientist/logs/setup_nanogpt_%j.log  # Save stdout
#SBATCH --error=/om2/user/raduba/AI-Scientist/logs/setup_nanogpt_%j.log   # Save stderr

# Load necessary modules and activate Conda environment
source /om2/user/raduba/anaconda/etc/profile.d/conda.sh
conda activate ai_scientist

# Ensure logs directory exists
mkdir -p /om2/user/raduba/AI-Scientist/logs || { echo "Failed to create logs directory"; exit 1; }

# Check available GPUs
available_gpus=$(nvidia-smi --query-gpu=name --format=csv,noheader)

if [ -z "$available_gpus" ]; then
  echo "No GPUs are currently available. Exiting."
  exit 1
fi

# Dynamically select preferred GPU with case-insensitive substring matching
preferred_gpus=("Tesla K20" "Tesla K80" "Tesla V100" "Titan Black" "Titan X" "RTX A6000" "A100" "GeForce RTX 2080" "RTX 2080 TI" "Quadro RTX 6000")
selected_gpu=""
for gpu in "${preferred_gpus[@]}"; do
  match=$(echo "$available_gpus" | grep -i "$gpu" | head -n 1)
  if [ -n "$match" ]; then
    selected_gpu=$match
    break
  fi
done

if [ -z "$selected_gpu" ]; then
  echo "No preferred GPU is currently available. Exiting."
  echo "Available GPUs: $available_gpus"
  exit 1
fi

echo "Selected GPU: $selected_gpu"

# Navigate to the project directory
cd /om2/user/raduba/AI-Scientist || { echo "Failed to navigate to /om2/user/raduba/AI-Scientist"; exit 1; }


# Set OpenAlex environment variable
export OPENALEX_MAIL_ADDRESS="raduba@mit.edu"  # Replace with your email

# Run the NanoGPT template experiment
python launch_scientist.py \
    --model "claude-3-5-sonnet-20241022" \
    --experiment nanoGPT \
    --num-ideas 1 \
    --engine openalex

echo "NanoGPT experiment completed successfully."