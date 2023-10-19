# This script installs GNU Parallel and defines several functions to run various commands in parallel.
# The script checks if GNU Parallel is already installed and installs it if it is not.
# It also adds the path to .local/bin to the shell's rc file.
# The script defines functions to run 'ls', 'date', 'df', 'du', 'grep', 'wc', 'awk', 'sort', 'zip', 'unzip', 
# fetch content from URLs, calculate SHA-256 hashes for files, encrypt and decrypt files, 
# perform parallel port scanning with nc (Netcat), remove duplicate lines from text files, 
# remove duplicate files based on SHA-256 hash, dedupe pre-sorted text files, 
# convert TXT to CSV, convert CSV to JSON, and convert JSON to CSV in parallel.
# Finally, it defines a function to perform log analysis in parallel.
#!/bin/bash

install_parallel() {
  # Check if parallel is already installed
  if command -v parallel &> /dev/null; then
    echo "GNU Parallel is already installed."
    return
  fi
  
  # Check if ~/.local/bin exists, if not create it
  if [ ! -d ~/.local/bin ]; then
    mkdir -p ~/.local/bin
  fi
  
  # Move to ~/.local/bin for installation
  cd ~/.local/bin
  
  # Download, extract, and install GNU Parallel
  wget http://ftp.gnu.org/gnu/parallel/parallel-latest.tar.bz2
  tar xjf parallel-latest.tar.bz2
  cd parallel-*/
  ./configure --prefix=$HOME/.local
  make && make install
  
  # Detect the current shell
  current_shell=$(basename "$SHELL")

  # Add the path to .local/bin to the shell's rc file
  if [[ $current_shell == 'bash' ]]; then
    echo 'export PATH=$PATH:~/.local/bin' >> ~/.bashrc
    source ~/.bashrc
  elif [[ $current_shell == 'zsh' ]]; then
    echo 'export PATH=$PATH:~/.local/bin' >> ~/.zshrc
    source ~/.zshrc
  else
    echo "Unsupported shell: $current_shell"
    echo "Please manually add ~/.local/bin to your PATH."
  fi
}


# Run the install function
install_parallel



# Function to run 'ls' in parallel
parallel_ls() {
  parallel -j $2 ls -l $1 ::: $(find $1 -maxdepth 1 -type d)
}

# Function to run 'date' in parallel
parallel_date() {
  parallel -j $1 date ::: {1..$1}
}

# Function to run 'df' in parallel
parallel_df() {
  parallel -j $1 df -h ::: {1..$1}
}



# Function to run 'du' in parallel
parallel_du() {
  parallel -j $2 du -sh $1/{} ::: $(ls -1 $1)
}

# Function to run 'grep' in parallel
parallel_grep() {
  parallel -j $3 grep -r $2 $1 ::: $(find $1 -type f)
}

# Function to run 'wc' in parallel
parallel_wc() {
  parallel -j $2 wc -l $1/{} ::: $(ls -1 $1)
}

# Function to run 'awk' in parallel
parallel_awk() {
  pattern=$2
  parallel -j $3 awk "'$pattern'" $1/{} ::: $(ls -1 $1)
}

# Function to run 'sort' in parallel
parallel_sort() {
  parallel -j $2 sort $1/{} -o $1/sorted_{} ::: $(ls -1 $1)
}

# Function to run 'zip' in parallel
parallel_zip() {
  parallel -j $2 zip -r $1/{}.zip $1/{} ::: $(ls -1 $1)
}

# Function to run 'unzip' in parallel
parallel_unzip() {
  parallel -j $2 unzip $1/{} -d $1/{}_unzipped ::: $(ls -1 $1/*.zip)
}

# Function to fetch content from URLs in parallel
parallel_url_content() {
  parallel -j $2 wget -O $1/{}_$2.html {} ::: $(cat $1)
}

# Function to calculate SHA-256 hashes for files in a directory in parallel
parallel_hash() {
  parallel -j $2 sha256sum $1/{} ::: $(ls -1 $1)
}

# Function to encrypt files in a directory in parallel
parallel_encrypt() {
  password=$3
  parallel -j $2 openssl enc -aes-256-cbc -salt -in $1/{} -out $1/{}.enc -k $password ::: $(ls -1 $1)
}

# Function to decrypt files in a directory in parallel
parallel_decrypt() {
  password=$3
  parallel -j $2 openssl enc -aes-256-cbc -d -in $1/{} -out $1/{}.dec -k $password ::: $(ls -1 $1/*.enc)
}

# Function to run parallel port scanning with nc (Netcat)
parallel_port_scan() {
  port=$2
  parallel -j $3 nc -zv -w1 {} $port ::: $(cat $1)
}


# Function to remove duplicate lines from text files in parallel
parallel_dedupe_lines() {
  parallel -j $2 "sort $1/{} | uniq > $1/{}_deduped" ::: $(ls -1 $1/*.txt)
}

# Function to remove duplicate files based on SHA-256 hash
parallel_dedupe_files() {
  # Generate hash for each file
  find $1 -type f -exec sha256sum {} + | sort > $1/hash_list.txt
  
  # Extract duplicate hashes
  awk '{print $1}' $1/hash_list.txt | uniq -d > $1/duplicate_hashes.txt
  
  # Remove duplicate files
  while read -r hash; do
    files=$(grep $hash $1/hash_list.txt | awk '{print $2}')
    first_file=""
    for file in $files; do
      if [ -z "$first_file" ]; then
        first_file="$file"
      else
        rm "$file"
      fi
    done
  done < $1/duplicate_hashes.txt
  
  # Cleanup
  rm $1/hash_list.txt $1/duplicate_hashes.txt
}

# Function to dedupe pre-sorted text files in parallel
parallel_dedupe_sorted_files() {
  parallel -j $2 "uniq $1/{} > $1/{}_deduped" ::: $(ls -1 $1/*.txt)
}

# Function to convert TXT to CSV in parallel
parallel_txt_to_csv() {
  parallel -j $2 "awk '{print gensub(/ /, \",\", \"g\", \$0)}' $1/{} > $1/{}.csv" ::: $(ls -1 $1/*.txt)
}

# Function to convert CSV to JSON in parallel
parallel_csv_to_json() {
  parallel -j $2 "python3 -c 'import csv, json; f = open(\"$1/{}\", \"r\"); reader = csv.DictReader(f); out = json.dumps([row for row in reader]); f.close(); f = open(\"$1/{}.json\", \"w\"); f.write(out); f.close()'" ::: $(ls -1 $1/*.csv)
}

# Function to convert JSON to CSV in parallel
parallel_json_to_csv() {
  parallel -j $2 "python3 -c 'import csv, json; f = open(\"$1/{}\", \"r\"); data = json.load(f); f.close(); f = open(\"$1/{}.csv\", \"w\", newline=\"\"); writer = csv.DictWriter(f, fieldnames=data[0].keys()); writer.writeheader(); writer.writerows(data); f.close()'" ::: $(ls -1 $1/*.json)
}

# Function to perform log analysis in parallel
parallel_log_analysis() {
  # $1 = directory containing log files
  # $2 = pattern to search for
  # $3 = number of parallel jobs
  
  # Create a directory to store the output files
  mkdir -p $1/analysis_results
  
  # Run grep on log files in parallel
  parallel -j $3 "grep -H -n '$2' $1/{} > $1/analysis_results/{}_matches" ::: $(ls -1 $1/*.log)
}

# Function to resize images in parallel
parallel_resize_images() {
  # $1 = directory containing images
  # $2 = width
  # $3 = height
  # $4 = number of parallel jobs
  
  parallel -j $4 "convert -resize ${2}x${3}! $1/{} $1/resized_{}" ::: $(ls -1 $1/*.jpg)
}
# Function to convert images to grayscale in parallel
parallel_to_grayscale() {
  # $1 = directory containing images
  # $2 = number of parallel jobs

  parallel -j $2 "convert -colorspace Gray $1/{} $1/gray_{}" ::: $(ls -1 $1/*.jpg)
}

# Function to rotate images in parallel
parallel_rotate_images() {
  # $1 = directory containing images
  # $2 = angle to rotate
  # $3 = number of parallel jobs

  parallel -j $3 "convert -rotate $2 $1/{} $1/rotated_{}" ::: $(ls -1 $1/*.jpg)
}

# Function to extract audio from video files in parallel
parallel_video_to_audio() {
  # $1 = directory containing video files
  # $2 = number of parallel jobs
  
  parallel -j $2 "ffmpeg -i $1/{} -q:a 0 -map a $1/{}.mp3 -y" ::: $(ls -1 $1/*.mp4)
}

# Function to resize video files in parallel
parallel_resize_video() {
  # $1 = directory containing video files
  # $2 = width
  # $3 = height
  # $4 = number of parallel jobs
  
  parallel -j $4 "ffmpeg -i $1/{} -vf scale=$2:$3 $1/resized_{} -y" ::: $(ls -1 $1/*.mp4)
}
# Function to convert audio files in parallel
parallel_convert_audio() {
  # $1 = directory containing audio files
  # $2 = target format (e.g., mp3, wav)
  # $3 = number of parallel jobs
  
  parallel -j $3 "ffmpeg -i $1/{} $1/{}.{$2} -y" ::: $(ls -1 $1/*.wav)
}

# Function to SCP files in parallel
parallel_scp() {
  # $1 = text file containing list of IPs
  # $2 = username
  # $3 = file to transfer
  # $4 = destination directory on remote server
  # $5 = number of parallel jobs
  
  parallel -j $5 "scp $3 ${2}@{}:$4" ::: $(cat $1)
}

# Function to run remote commands in parallel
parallel_remote_cmd() {
  # $1 = text file containing list of IPs
  # $2 = username
  # $3 = command to run
  # $4 = number of parallel jobs
  
  parallel -j $4 "ssh ${2}@{} $3" ::: $(cat $1)
}

# Function to bulk insert data in parallel
parallel_bulk_insert() {
  # $1 = Database connection string
  # $2 = Database type ('mysql' or 'postgresql')
  # $3 = Table name
  # $4 = Directory containing CSV files
  # $5 = Number of parallel jobs
  
  if [ "$2" == "mysql" ]; then
    parallel -j $5 "$1 -e 'LOAD DATA LOCAL INFILE \"$4/{}\" INTO TABLE $3 FIELDS TERMINATED BY \",\" ENCLOSED BY \"\"\" LINES TERMINATED BY \"\n\"'" ::: $(ls -1 $4/*.csv)
  elif [ "$2" == "postgresql" ]; then
    parallel -j $5 "$1 -c '\COPY $3 FROM ''$4/{}'' WITH CSV'" ::: $(ls -1 $4/*.csv)
  else
    echo "Unsupported database type: $2"
  fi
}

# Function to bulk update data in parallel
parallel_bulk_update() {
  # $1 = Database connection string
  # $2 = Directory containing SQL files for updates
  # $3 = Number of parallel jobs
  parallel -j $3 "$1 < $2/{}" ::: $(ls -1 $2/*.sql)
}
# Function to bulk delete data in parallel
parallel_bulk_delete() {
  # $1 = Database connection string
  # $2 = Directory containing SQL files for deletes
  # $3 = Number of parallel jobs
  parallel -j $3 "$1 < $2/{}" ::: $(ls -1 $2/*.sql)
}


