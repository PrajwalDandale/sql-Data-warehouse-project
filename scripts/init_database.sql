/*
=============================================================
Create Database
=============================================================
Script Purpose:
This script creates a new database named 'bronze','silver' and 'gold' after checking if it already exists.

WARNING:
Running this script will drop the entire database if it exists.
All data in the database will be permanently deleted. Proceed with caution and ensure you have proper backups before runnning this script.
*/



-- Drop the databases if exists
DROP DATABASE IF EXISTS bronze;
DROP DATABASE IF EXISTS silver;
DROP DATABASE IF EXISTS gold;

-- Create databases
CREATE DATABASE bronze;
CREATE DATABASE silver;
CREATE DATABASE gold;
