import mysql.connector
from faker import Faker
import random
from datetime import date, timedelta

# --- Configuration de la connexion ---
DB_CONFIG = {
    'host': 'localhost',
    'port': 3307,
    'user': 'root',
    'password': 'rootpassword',
    'database': 'db'
}

fake = Faker('fr_FR')





def connect_db():
    return mysql.connector.connect(**DB_CONFIG)


def create_user(cursor):
    cursor.execute("""
        INSERT INTO Utilisateurs (nomUtilisateur, prenomUtilisateur, login, mdp, hashcode, ville, codePostal)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
    """, ('Durand', 'Lucie', 'lucie.durand', 'password', 'hash123456', 'Paris', '75001'))
    return cursor.lastrowid


def create_comptes(cursor, id_user):
    comptes_info = [
        ("Compte courant personnel", "BNP Paribas"),
        ("Compte epargne", "Credit Agricole"),
        ("Compte commun", "Societe Generale"),
        ("Compte crypto", "Revolut")
    ]
    id_comptes = []

    for desc, banque in comptes_info:
        cursor.execute("""
            INSERT INTO Comptes (descriptionCompte, nomBanque, idUtilisateur)
            VALUES (%s, %s, %s)
        """, (desc, banque, id_user))
        id_comptes.append(cursor.lastrowid)

    return id_comptes


def create_categories(cursor):
    categories = {
        "Alimentation": ["Courses", "Restaurants"],
        "Transport": ["Essence", "Train", "Velo"],
        "Loisirs": ["Cinema", "Jeux", "Voyages"],
        "Sante": ["Medecin", "Pharmacie"],
        "Logement": ["Loyer", "electricite", "Internet"],
        "Revenus": ["Salaire", "Allocations", ],
        "Epargne": []
    }

    categorie_ids = {}
    souscategorie_ids = {}

    for cat, souscats in categories.items():
        cursor.execute("INSERT INTO Categories (nomCategorie) VALUES (%s)", (cat,))
        cat_id = cursor.lastrowid
        categorie_ids[cat] = cat_id
        for souscat in souscats:
            cursor.execute("INSERT INTO SousCategories (nomSousCategorie, idCategorie) VALUES (%s, %s)",
                           (souscat, cat_id))
            souscategorie_ids[souscat] = cursor.lastrowid

    return categorie_ids, souscategorie_ids


def create_tiers(cursor, id_user, n=10):
    tiers_ids = []
    for _ in range(n):
        cursor.execute("INSERT INTO Tiers (nomTiers, idUtilisateur) VALUES (%s, %s)", (fake.company(), id_user))
        tiers_ids.append(cursor.lastrowid)
    return tiers_ids


def get_or_create_tiers(cursor, nom, id_user):
    cursor.execute("SELECT idTiers FROM Tiers WHERE nomTiers = %s", (nom,))
    res = cursor.fetchone()
    if res:
        return res[0]
    cursor.execute("INSERT INTO Tiers (nomTiers, idUtilisateur) VALUES (%s, %s)", (nom, id_user))
    return cursor.lastrowid


def generate_mouvements(cursor, id_user, id_compte, categorie_ids, souscategorie_ids, autres_tiers_ids):
    current_date = date(2017, 1, 1)
    end_date = date(2025, 1, 1)
    inflation_rate = 0.03

    salaire_tiers = get_or_create_tiers(cursor, "Entreprise XYZ", id_user)
    supermarche_tiers = get_or_create_tiers(cursor, "Supermarche Leclerc", id_user)
    bailleur_tiers = get_or_create_tiers(cursor, "Proprietaire Bailleur", id_user)

    while current_date < end_date:
        annee = current_date.year - 2017
        inflation = (1 + inflation_rate) ** annee

        # Salaire mensuel
        salaire = round(random.uniform(2200, 2800) * inflation, 2)
        cursor.execute("""
            INSERT INTO Mouvements (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
            VALUES (%s, %s, %s, %s, %s, %s, 'C')
        """, (
            date(current_date.year, current_date.month, 25),
            id_compte,
            salaire_tiers,
            categorie_ids["Revenus"],
            souscategorie_ids["Salaire"],
            salaire
        ))

        # Loyer mensuel
        loyer = -1 * round(random.uniform(850, 1100) * inflation, 2)
        cursor.execute("""
            INSERT INTO Mouvements (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
            VALUES (%s, %s, %s, %s, %s, %s, 'D')
        """, (
            date(current_date.year, current_date.month, 2),
            id_compte,
            bailleur_tiers,
            categorie_ids["Logement"],
            souscategorie_ids["Loyer"],
            loyer
        ))

        # Courses hebdo
        for week in range(4):
            d = current_date + timedelta(days=week * 7 + 3)
            montant = -1 * round(random.uniform(50, 130) * inflation, 2)
            cursor.execute("""
                INSERT INTO Mouvements (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
                VALUES (%s, %s, %s, %s, %s, %s, 'D')
            """, (
                d,
                id_compte,
                supermarche_tiers,
                categorie_ids["Alimentation"],
                souscategorie_ids["Courses"],
                montant
            ))

        # Loisirs
        for _ in range(random.randint(1, 2)):
            d = current_date + timedelta(days=random.randint(5, 25))
            montant = round(random.uniform(20, 100) * inflation, 2)
            cursor.execute("""
                INSERT INTO Mouvements (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
                VALUES (%s, %s, %s, %s, %s, %s, 'D')
            """, (
                d,
                id_compte,
                random.choice(autres_tiers_ids),
                categorie_ids["Loisirs"],
                souscategorie_ids["Cinema"],
                montant
            ))

        # Avancer d'un mois
        current_date = (current_date.replace(day=1) + timedelta(days=32)).replace(day=1)


def generate_virements(cursor, id_user, compte1_id):
    # Crée un autre compte épargne
    cursor.execute("INSERT INTO Comptes (descriptionCompte, nomBanque, idUtilisateur) VALUES (%s, %s, %s)",
                   ("Livret A", "BNP Paribas", id_user))
    compte2_id = cursor.lastrowid

    # Get categorie "Epargne" for Virements
    cursor.execute("SELECT idCategorie FROM Categories WHERE nomCategorie = 'Epargne'")
    id_categorie_epargne = cursor.fetchone()[0]

    for _ in range(20):
        montant = round(random.uniform(50, 500), 2)
        date_virement = fake.date_between(start_date='-6M', end_date='today')
        cursor.execute("""
            INSERT INTO Virements (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
            VALUES (%s, %s, %s, %s, %s)
        """, (compte1_id, compte2_id, montant, date_virement, id_categorie_epargne))


def main():
    conn = connect_db()
    cursor = conn.cursor()

    id_user = create_user(cursor)
    comptes = create_comptes(cursor, id_user)
    id_compte_courant = comptes[0]

    categorie_ids, souscategorie_ids = create_categories(cursor)
    autres_tiers_ids = create_tiers(cursor, id_user)

    generate_mouvements(cursor, id_user, id_compte_courant, categorie_ids, souscategorie_ids, autres_tiers_ids)
    generate_virements(cursor, id_user, id_compte_courant)

    conn.commit()
    cursor.close()
    conn.close()
    print("✅ Donnees generees avec succès.")


if __name__ == "__main__":
    main()
