#!/bin/bash
## to be updated to match your settings
PROJECT_HOME="."
credentials_file="$PROJECT_HOME/data/credentials.txt"
logged_in_file="$PROJECT_HOME/data/.logged_in"

# Function to prompt for credentials
get_credentials() {
    read -p 'Username: ' user
    read -rs -p 'Password: ' pass
    echo
}

generate_salt() {
    openssl rand -hex 8
    return 0
}

## function for hashing
hash_password() {
    password=$1
    salt=$2
    echo -n "${password}${salt}" | sha256sum | awk '{print $1}'
    return 0
}

check_existing_username(){
    username=$1
    if grep -q "^${username}:" "$credentials_file"; then
        return 0
    else
        return 1
    fi
}

## function to add new credentials to the file
register_credentials() {
    username=$1
    password=$2
    fullname=$3
    role=${4:-"normal"}

    check_existing_username $username
    if [ $? -eq 0 ]; then
        echo "Username already exists. Registration failed."
        return 1
    fi

    if [[ $role != "normal" && $role != "salesperson" && $role != "admin" ]]; then
        echo "Invalid role. Role should be normal, salesperson, or admin."
        return 1
    fi

    salt=$(generate_salt)
    hashed_pwd=$(hash_password $password $salt)
    echo "$username:$hashed_pwd:$salt:$fullname:$role:0" >> "$credentials_file"
    echo "Registration Successfull. You can now Login"
}

# Function to verify credentials
verify_credentials() {
    username=$1
    password=$2

    if ! line=$(grep "^${username}:" "$credentials_file"); then
        echo "Invalid credentials"
        return 1
    fi

    stored_hash=$(echo $line | cut -d':' -f2)
    stored_salt=$(echo $line | cut -d':' -f3)
    computed_hash=$(hash_password $password $stored_salt)

    if [ "$computed_hash" = "$stored_hash" ]; then
        
        echo "$username" > "$logged_in_file"
        sed -i "s/^$line$/${line%:*}:1/" "$credentials_file"
        echo "Welcome "$fullname" You have successfully logged in as "$role"."
        return 0
    else
        echo "Invalid password."
        return 1
    fi
}

logout() {
    if [ -s "$logged_in_file" ]; then
        username=$(cat "$logged_in_file")
        rm -f "$logged_in_file"
        sed -i "s/^$username:.*$/&:0/" "$credentials_file"
        echo "Logged out successfully."
    else
        echo "No user is currently logged in."
    fi
}

# Menu for the application
while true; do
    echo "1. Login"
    echo "2. Register"
    echo "3. Logout"
    echo "4. Close the program"
    read -p "Enter your Choice : " choice

    case $choice in
        1)
            echo "==== Login ===="
            get_credentials
            verify_credentials "$user" "$pass"
            ;;
        2)
            echo "====User Registration===="
            read -p "Username: " new_user
            read -rs -p "Password: " new_pass
            echo
            read -p "Enter name: " fullname
            read -p "Role (admin/normal/salesperson, default: normal): " role
            register_credentials "$new_user" "$new_pass" "$fullname" "$role"
            ;;
        3)
            exit 0
            ;;
        *)
            echo "Invalid Choise. Please choose again."
            ;;
    esac
done
