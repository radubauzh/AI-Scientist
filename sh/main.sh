#!/bin/bash
#SBATCH --partition=use-everything      # Target the partition with newer GPUs
#SBATCH --gres=gpu:1                    # Request 1 GPU, model to be selected dynamically
#SBATCH --time=30:00:00                 # Set a time limit for the job
#SBATCH --mem=16G                       # Set memory limit (e.g., 16 GB)
#SBATCH --cpus-per-task=4               # Allocate 4 CPU cores
#SBATCH --job-name=MainNano             # Set a name for the job
#SBATCH --output=/om2/user/raduba/AI-Scientist/logs/main_nanoGPT_%j.log  # Save stdout
#SBATCH --error=/om2/user/raduba/AI-Scientist/logs/main_nanoGPT_error_%j.log   # Save stderr

# Load necessary modules and activate Conda environment
source /om2/user/raduba/anaconda/etc/profile.d/conda.sh
conda activate ai_scientist

# Ensure logs directory exists
mkdir -p /om2/user/raduba/AI-Scientist/logs || { echo "Failed to create logs directory"; exit 1; }

# Step 1: Load API keys and sensitive data from a secure configuration file
CONFIG_FILE="/om2/user/raduba/AI-Scientist/config.env"
if [ -f "$CONFIG_FILE" ]; then
    echo "Loading configuration from $CONFIG_FILE"
    export $(grep -v '^#' $CONFIG_FILE | xargs)
else
    echo "Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Just to confirm keys are loaded (optional, comment out in production)
echo "Configuration loaded successfully."

# Just to confirm they're set:
echo "ANTHROPIC_API_KEY: $ANTHROPIC_API_KEY"
echo "OPENAI_API_KEY: $OPENAI_API_KEY"
echo "OPENALEX_MAIL_ADDRESS: $OPENALEX_MAIL_ADDRESS"

# Define preferred GPUs
preferred_gpus=("Tesla K20" "Tesla K80" "Tesla V100" "Titan Black" "Titan X" "RTX A6000" "A100" "GeForce RTX 2080" "RTX 2080 TI" "Quadro RTX 6000")

echo "Checking for preferred GPUs..."
while true; do
  # Check available GPUs
  available_gpus=$(nvidia-smi --query-gpu=name --format=csv,noheader)

  if [ -z "$available_gpus" ]; then
    echo "No GPUs are currently available. Waiting 30 seconds before retrying..."
    sleep 30
    continue
  fi

  # Dynamically select preferred GPU with case-insensitive substring matching
  selected_gpu=""
  for gpu in "${preferred_gpus[@]}"; do
    match=$(echo "$available_gpus" | grep -i "$gpu" | head -n 1)
    if [ -n "$match" ]; then
      selected_gpu=$match
      break
    fi
  done

  if [ -n "$selected_gpu" ]; then
    echo "Selected GPU: $selected_gpu"
    break
  else
    echo "No preferred GPU is currently available. Waiting 45 seconds before retrying..."
    echo "Available GPUs: $available_gpus"
    sleep 45
  fi
done

# Navigate to the project directory
cd /om2/user/raduba/AI-Scientist || { echo "Failed to navigate to /om2/user/raduba/AI-Scientist"; exit 1; }

# Step 1: Prepare the data
echo "Preparing data..."
python data/enwik8/prepare.py || { echo "Failed to prepare enwik8 data"; exit 1; }
python data/shakespeare_char/prepare.py || { echo "Failed to prepare shakespeare_char data"; exit 1; }
python data/text8/prepare.py || { echo "Failed to prepare text8 data"; exit 1; }

# Step 2: Set up baseline run for NanoGPT
echo "Running baseline experiment..."
cd templates/nanoGPT || { echo "Failed to navigate to templates/nanoGPT"; exit 1; }
python experiment.py --out_dir run_0 || { echo "Failed to run baseline experiment"; exit 1; }

# Step 3: Generate baseline plots
echo "Generating plots..."
python plot.py || { echo "Failed to generate plots"; exit 1; }

echo "NanoGPT setup completed successfully."


cd /om2/user/raduba/AI-Scientist
echo "Launching Scientist"
# Step 5: Run the NanoGPT template experiment
python launch_scientist.py \
    --model "gpt-4o-2024-08-06" \
    --experiment nanoGPT \
    --num-ideas 1 \
    --engine openalex

echo "NanoGPT experiment completed successfully."
