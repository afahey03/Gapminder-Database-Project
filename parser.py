import csv
import mysql.connector

# --- Database connection ---
db = mysql.connector.connect(
    host="localhost",
    user="root",
    passwd="072003Af",
    database="countries"
)

cursor = db.cursor()

# --- Helper: Clean and normalize headers ---
def sanitize_headers(headers):
    return [h.strip().lower().replace(" ", "_") for h in headers]

# --- Insert Continents ---
def insert_continents():
    continents = set()
    with open('data.csv', 'r', encoding='utf-8-sig') as file:
        reader = csv.DictReader(file)
        reader.fieldnames = sanitize_headers(reader.fieldnames)
        for row in reader:
            continents.add(row['continent'].strip())
    
    for continent in continents:
        cursor.execute("""
            INSERT INTO Continent (continent_name)
            VALUES (%s)
            ON DUPLICATE KEY UPDATE continent_name = VALUES(continent_name)
        """, (continent,))
        db.commit()

# --- Insert Countries ---
def insert_countries():
    with open('data.csv', 'r', encoding='utf-8-sig') as file:
        reader = csv.DictReader(file)
        reader.fieldnames = sanitize_headers(reader.fieldnames)
        for row in reader:
            cursor.execute("""
                INSERT INTO Country (country_name, iso_alpha, iso_num)
                VALUES (%s, %s, %s)
                ON DUPLICATE KEY UPDATE country_name = VALUES(country_name)
            """, (row['country'], row['iso_alpha'], int(row['iso_num'])))
            db.commit()

# --- Link Countries to Continents ---
def insert_country_continent_links():
    with open('data.csv', 'r', encoding='utf-8-sig') as file:
        reader = csv.DictReader(file)
        reader.fieldnames = sanitize_headers(reader.fieldnames)
        for row in reader:
            cursor.execute("SELECT country_id FROM Country WHERE country_name = %s", (row['country'],))
            country_result = cursor.fetchone()
            if not country_result:
                continue
            country_id = country_result[0]

            cursor.execute("SELECT continent_id FROM Continent WHERE continent_name = %s", (row['continent'],))
            continent_result = cursor.fetchone()
            if not continent_result:
                continue
            continent_id = continent_result[0]

            cursor.execute("""
                INSERT IGNORE INTO Country_Continent (country_id, continent_id)
                VALUES (%s, %s)
            """, (country_id, continent_id))
            db.commit()

# --- Insert Years ---
def insert_years():
    years = set()
    with open('data.csv', 'r', encoding='utf-8-sig') as file:
        reader = csv.DictReader(file)
        reader.fieldnames = sanitize_headers(reader.fieldnames)
        for row in reader:
            years.add(int(row['year']))
    
    for year in years:
        cursor.execute("""
            INSERT INTO Years (year_value)
            VALUES (%s)
            ON DUPLICATE KEY UPDATE year_value = VALUES(year_value)
        """, (year,))
        db.commit()

# --- Get GDP Category ID ---
def get_gdp_category_id(gdp):
    cursor.execute("SELECT gdp_category_id FROM GDP_Category WHERE %s BETWEEN min_gdp AND max_gdp", (gdp,))
    result = cursor.fetchone()
    return result[0] if result else None

# --- Insert Metrics ---
# --- Insert Economic Metrics ---
def insert_economic_metrics():
    with open('data.csv', 'r', encoding='utf-8-sig') as file:
        reader = csv.DictReader(file)
        reader.fieldnames = sanitize_headers(reader.fieldnames)
        for row in reader:
            # Get country_id
            cursor.execute("SELECT country_id FROM Country WHERE country_name = %s", (row['country'],))
            country_result = cursor.fetchone()
            if not country_result:
                continue
            country_id = country_result[0]

            # Get year_id
            cursor.execute("SELECT year_id FROM Years WHERE year_value = %s", (int(row['year']),))
            year_result = cursor.fetchone()
            if not year_result:
                continue
            year_id = year_result[0]

            # Get GDP category ID
            gdp = float(row['gdppercap']) if row['gdppercap'] else 0.0
            gdp_cat_id = get_gdp_category_id(gdp)

            # Insert into EconomicMetrics table
            cursor.execute("""
                INSERT INTO EconomicMetrics (country_id, year_id, gdp_per_capita, gdp_category_id)
                VALUES (%s, %s, %s, %s)
                ON DUPLICATE KEY UPDATE 
                    gdp_per_capita = VALUES(gdp_per_capita),
                    gdp_category_id = VALUES(gdp_category_id)
            """, (
                country_id,
                year_id,
                gdp,
                gdp_cat_id
            ))
            db.commit()


# --- Run all functions ---
insert_continents()
insert_countries()
insert_country_continent_links()
insert_years()
insert_economic_metrics()

# --- Close DB connection ---
cursor.close()
db.close()