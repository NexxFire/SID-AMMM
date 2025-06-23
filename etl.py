import mysql.connector
from datetime import timedelta

def connect_db(host, port, user, password, database):
    return mysql.connector.connect(
        host=host,
        port=port,
        user=user,
        password=password,
        database=database
    )

def clear_target_database(cursor):
    # ⚠️ L'ordre est important à cause des contraintes de clés étrangères
    tables = [
        "Soldes",
        "Transactions",
        "Virements",
        "Temps",
        "SousCategories",
        "Categories",
        "Comptes"
    ]
    cursor.execute("SET FOREIGN_KEY_CHECKS = 0")  # Désactiver les contraintes de clés étrangères
    for table in tables:
        cursor.execute(f"DELETE FROM {table}")
    cursor.execute("SET FOREIGN_KEY_CHECKS = 1")  # Réactiver les contraintes de clés étrangères


def etl_categories(source_cursor, target_cursor):
    source_cursor.execute("SELECT * FROM Categories")
    for row in source_cursor.fetchall():
        target_cursor.execute("""
            INSERT INTO Categories (nom)
            VALUES (%s)
        """, (row["nomCategorie"],))

    source_cursor.execute("SELECT * FROM SousCategories")
    for row in source_cursor.fetchall():
        target_cursor.execute("""
            INSERT INTO SousCategories (nom, idCategorie)
            VALUES (%s, %s)
        """, (row["nomSousCategorie"], row["idCategorie"]))

def etl_comptes(source_cursor, target_cursor):
    source_cursor.execute("SELECT * FROM Comptes")
    for row in source_cursor.fetchall():
        target_cursor.execute("""
            INSERT INTO Comptes (banque, description)
            VALUES (%s, %s)
        """, (row["nomBanque"], row["descriptionCompte"]))

def etl_temps(source_cursor, target_cursor):
    source_cursor.execute("""
        SELECT MIN(DATE(dateMouvement)) AS min_date,
            MAX(DATE(dateMouvement)) AS max_date
        FROM Mouvements
    """)
    row = source_cursor.fetchone()

    min_date = row["min_date"]
    max_date = row["max_date"]

    current_date = min_date
    id_date_map = {}
    id_counter = 1

    while current_date <= max_date:
        jour = current_date.day
        mois = current_date.month
        annee = current_date.year
        jourJulien = current_date.timetuple().tm_yday
        nomJour = current_date.strftime('%A')
        target_cursor.execute("""
            INSERT INTO Temps (id, jour, mois, annee, jourJulien, nomJour)
            VALUES (%s, %s, %s, %s, %s, %s)
        """, (id_counter, jour, mois, annee, jourJulien, nomJour))

        id_date_map[str(current_date)] = id_counter
        id_counter += 1
        current_date += timedelta(days=1)

    return id_date_map

def etl_virements(source_cursor, target_cursor, id_date_map):
    source_cursor.execute("SELECT * FROM Virements")
    for row in source_cursor.fetchall():
        date = row["dateVirement"].strftime('%Y-%m-%d')
        idDate = id_date_map.get(date)
        target_cursor.execute("""
            INSERT INTO Virements (idCompteDebiteur, idCompteCrediteur, montant, idDate)
            VALUES (%s, %s, %s, %s)
        """, (row["idCompteDebit"], row["idCompteCredit"], float(row["montant"]), idDate))

def etl_transactions(source_cursor, target_cursor, id_date_map):
    source_cursor.execute("SELECT * FROM Mouvements")
    for row in source_cursor.fetchall():
        date = row["dateMouvement"].strftime('%Y-%m-%d')
        idDate = id_date_map.get(date)
        type_mvt = row["typeMouvement"]
        # montant = row["montant"] if type_mvt == 'C' else -1 * row["montant"]

        nomTiers = None
        if row["idTiers"]:
            source_cursor.execute("SELECT nomTiers FROM Tiers WHERE idTiers = %s", (row["idTiers"],))
            result = source_cursor.fetchone()
            if result:
                nomTiers = result["nomTiers"]

        target_cursor.execute("""
            INSERT INTO Transactions (montant, idDate, type, idCategorie, idSousCategorie, nomTiers, idCompte)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
        """, (
            row["montant"],
            idDate,
            type_mvt,
            row["idCategorie"],
            row["idSousCategorie"],
            nomTiers,
            row["idCompte"]
        ))

def etl_soldes(source_cursor, target_cursor):
    # Étape 1 : récupérer toutes les dates dans l'ordre (depuis la table Temps)
    target_cursor.execute("SELECT id, annee, mois, jour FROM Temps ORDER BY annee, mois, jour")
    dates = target_cursor.fetchall()

    # Étape 2 : récupérer tous les comptes
    source_cursor.execute("SELECT idCompte FROM Comptes")
    comptes = source_cursor.fetchall()

    for compte_row in comptes:
        idCompte = compte_row["idCompte"]
        solde = 1000.0  # solde initial

        for date_row in dates:
            idDate = date_row[0]
            annee, mois, jour = date_row[1], date_row[2], date_row[3]
            date_str = f"{annee:04d}-{mois:02d}-{jour:02d}"

            # Récupérer tous les mouvements de ce compte à cette date
            source_cursor.execute("""
                SELECT typeMouvement, montant 
                FROM Mouvements 
                WHERE idCompte = %s AND DATE(dateMouvement) = %s
            """, (idCompte, date_str))

            mouvements = source_cursor.fetchall()

            for m in mouvements:
                if m["typeMouvement"] == 'C':  # Crédit
                    solde += float(m["montant"])
                else:  # Débit
                    solde -= float(m["montant"])

            # Insérer le solde du jour
            target_cursor.execute("""
                INSERT INTO Soldes (solde, idDate, idCompte)
                VALUES (%s, %s, %s)
            """, (solde, idDate, idCompte))


def main():
    # Connexions
    source_conn = connect_db("localhost", 3307, "root", "rootpassword", "db")
    target_conn = connect_db("localhost", 3308, "root", "rootpassword", "db")

    source_cursor = source_conn.cursor(dictionary=True)
    target_cursor = target_conn.cursor()

    # ETL process
    clear_target_database(target_cursor)
    etl_categories(source_cursor, target_cursor)
    etl_comptes(source_cursor, target_cursor)
    id_date_map = etl_temps(source_cursor, target_cursor)
    etl_virements(source_cursor, target_cursor, id_date_map)
    etl_transactions(source_cursor, target_cursor, id_date_map)
    etl_soldes(source_cursor, target_cursor)

    # Commit et fermeture
    target_conn.commit()
    source_cursor.close()
    target_cursor.close()
    source_conn.close()
    target_conn.close()

if __name__ == "__main__":
    main()
