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
    echo "Registration Successful. You can now Login."
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
        fullname=$(echo $line | cut -d':' -f4)
        role=$(echo $line | cut -d':' -f5)
        echo "$username" > "$logged_in_file"
        sed -i "s/^$line$/${line%:*}:1/" "$credentials_file"
        echo "Welcome $fullname You have successfully logged in as $role."
        return 0
    else
        echo "Invalid password."
        return 1
    fi
}

# Function to create admin user
create_admin() {
    current_user=$(cat "$logged_in_file")
    current_user_role=$(grep "^$current_user:" "$credentials_file" | cut -d':' -f5)
    if [ "$current_user_role" = "admin" ]; then
        read -p "Enter username for the new admin: " new_admin_user
        read -rs -p "Enter password for the new admin: " new_admin_pass
        echo
        read -p "Enter full name for the new admin: " new_admin_fullname
        register_credentials "$new_admin_user" "$new_admin_pass" "$new_admin_fullname" "admin"
        echo "Admin $new_admin_fullname successfully created by $current_user."
    else
        echo "You need to be an admin to create an admin."
    fi
}

# Function to create salesperson
create_salesperson() {
    if [ -s "$logged_in_file" ]; then
        current_user=$(cat "$logged_in_file")
        current_user_role=$(grep "^$current_user:" "$credentials_file" | cut -d':' -f5)
        if [ "$current_user_role" = "admin" ]; then
            read -p "Enter username for the new salesperson: " new_salesperson_user
            read -rs -p "Enter password for the new salesperson: " new_salesperson_pass
            echo
            read -p "Enter full name for the new salesperson: " new_salesperson_fullname
            register_credentials "$new_salesperson_user" "$new_salesperson_pass" "$new_salesperson_fullname" "salesperson"
            echo "Salesperson $new_salesperson_fullname successfully created by $current_user."
        else
            echo "You need to be an admin to create a salesperson."
        fi
    else
        echo "You need to be logged in as admin to create a salesperson."
    fi
}


# Function to create normal user by admin
create_normal_user() {
    if [ -s "$logged_in_file" ]; then
        current_user=$(cat "$logged_in_file")
        current_user_role=$(grep "^$current_user:" "$credentials_file" | cut -d':' -f5)
        if [ "$current_user_role" = "admin" ]; then
            read -p "Enter username for the new user: " new_user_user
            read -rs -p "Enter password for the new user: " new_user_pass
            echo
            read -p "Enter full name for the new user: " new_user_fullname
            register_credentials "$new_user_user" "$new_user_pass" "$new_user_fullname" "normal"
            echo "User $new_user_fullname successfully created by $current_user."
        else
            echo "You need to be an admin to create a user."
        fi
    else
        echo "You need to be logged in as admin to create a user."
    fi
}

# Function to logout
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
    if [ -s "$logged_in_file" ]; then
        current_user=$(cat "$logged_in_file")
        current_user_role=$(grep "^$current_user:" "$credentials_file" | cut -d':' -f5)
        if [ "$current_user_role" = "admin" ]; then
            echo "Admin Menu:"
            echo "1. Create Admin"
            echo "2. Create Salesperson"
            echo "3. Create Normal User"
        fi
    fi

    echo "Main Menu:"
    echo "1. Login"
    echo "2. Register"
    echo "3. Logout"
    echo "4. Close the program"
    read -p "Enter your Choice: " choice

    case $choice in
        1)
            echo "==== Login ===="
            get_credentials
            verify_credentials "$user" "$pass"
            ;;
        2)
            echo "==== User Registration ===="
            read -p "Username: " new_user
            read -rs -p "Password: " new_pass
            echo
            read -p "Enter name: " fullname
            read -p "Role (admin or normal default: normal): " role
            register_credentials "$new_user" "$new_pass" "$fullname" "$role"
            ;;
        3)
            logout
            ;;
        4)
            echo "Closing the program. Goodbye!"
            exit 0
            ;;
        *)
            if [ "$current_user_role" = "admin" ]; then
                case $choice in
                    1)
                        create_admin
                        ;;
                    2)
                        create_salesperson
                        ;;
                    3)
                        create_normal_user
                        ;;
                    *)
                        echo "Invalid Choice. Please choose again."
                        ;;
                esac
            else
                echo "Invalid Choice. Please choose again."
            fi
            ;;
    esac
done
