import pymysql
from datetime import datetime

# Configuration des bases
SRC_DB = {
    "host": "localhost:3307",
    "user": "root",
    "password": "rootpassword",
    "database": "db-transaction"
}

DST_DB = {
    "host": "localhost:3308",
    "user": "root",
    "password": "rootpassword",
    "database": "db-decision"
}

class Migrator:
    def __init__(self):
        self.src_conn = pymysql.connect(**SRC_DB, cursorclass=pymysql.cursors.DictCursor)
        self.dst_conn = pymysql.connect(**DST_DB, cursorclass=pymysql.cursors.DictCursor)
        self._init_metadata()

    def _init_metadata(self):
        with self.dst_conn.cursor() as cur:
            cur.execute("""
                CREATE TABLE IF NOT EXISTS MigrationMetadata (
                    table_name VARCHAR(255) PRIMARY KEY,
                    last_migration TIMESTAMP
                )
            """)
            self.dst_conn.commit()

    def _get_last_migration(self, table_name):
        with self.dst_conn.cursor() as cur:
            cur.execute("SELECT last_migration FROM MigrationMetadata WHERE table_name = %s", (table_name,))
            result = cur.fetchone()
            return result['last_migration'] if result else None

    def _update_last_migration(self, table_name):
        with self.src_conn.cursor() as cur:
            cur.execute(f"SELECT MAX(dateHeureMAJ) AS max_ts FROM {table_name}")
            max_ts = cur.fetchone()['max_ts']
        
        with self.dst_conn.cursor() as cur:
            cur.execute("""
                INSERT INTO MigrationMetadata (table_name, last_migration)
                VALUES (%s, %s)
                ON DUPLICATE KEY UPDATE last_migration = VALUES(last_migration)
            """, (table_name, max_ts))
            self.dst_conn.commit()

    def migrate_categories(self):
        last_migration = self._get_last_migration("Categorie")
        query = """
            SELECT * FROM Categorie
            WHERE dateHeureMAJ > %s OR %s IS NULL
        """
        
        with self.src_conn.cursor() as src_cur, self.dst_conn.cursor() as dst_cur:
            src_cur.execute(query, (last_migration, last_migration))
            
            for row in src_cur:
                dst_cur.execute("""
                    INSERT INTO Catégorie (id, nom, dateHeureCréation, dateHeureMaj)
                    VALUES (%(idCategorie)s, %(nomCategorie)s, %(dateHeureCreation)s, %(dateHeureMAJ)s)
                    ON DUPLICATE KEY UPDATE
                    nom = VALUES(nom),
                    dateHeureMaj = VALUES(dateHeureMaj)
                """, row)
            
            self.dst_conn.commit()
            self._update_last_migration("Categorie")

    def migrate_comptes(self):
        last_migration = self._get_last_migration("Compte")
        query = """
            SELECT * FROM Compte
            WHERE dateHeureMAJ > %s OR %s IS NULL
        """
        
        with self.src_conn.cursor() as src_cur, self.dst_conn.cursor() as dst_cur:
            src_cur.execute(query, (last_migration, last_migration))
            
            for row in src_cur:
                dst_cur.execute("""
                    INSERT INTO Compte (id, banque, description)
                    VALUES (%(idCompte)s, %(nomBanque)s, %(descriptionCompte)s)
                    ON DUPLICATE KEY UPDATE
                    banque = VALUES(banque),
                    description = VALUES(description)
                """, row)
            
            self.dst_conn.commit()
            self._update_last_migration("Compte")

    def _process_temps(self, date_str):
        date_obj = datetime.strptime(date_str, "%Y-%m-%d")
        mois = date_obj.month
        annee = date_obj.year
        mois_annee = f"{annee}-{mois:02d}"
        
        with self.dst_conn.cursor() as cur:
            cur.execute("""
                INSERT INTO Temps (nom, mois, année, moisAnnée)
                VALUES (%s, %s, %s, %s)
                ON DUPLICATE KEY UPDATE id=LAST_INSERT_ID(id)
            """, (date_str, mois, annee, mois_annee))
            
            return cur.lastrowid

    def migrate_transactions(self):
        last_migration = self._get_last_migration("Mouvement")
        query = """
            SELECT m.*, t.nomTiers 
            FROM Mouvement m
            LEFT JOIN Tiers t ON m.idTiers = t.idTiers
            WHERE m.dateHeureMAJ > %s OR %s IS NULL
        """
        
        with self.src_conn.cursor() as src_cur, self.dst_conn.cursor() as dst_cur:
            src_cur.execute(query, (last_migration, last_migration))
            
            for row in src_cur:
                temps_id = self._process_temps(str(row['dateMouvement']))
                type_txt = 'Crédit' if row['typeMouvement'] == 'C' else 'Débit'
                
                dst_cur.execute("""
                    INSERT INTO Transactions (
                        id, montant, date, type, 
                        idCatégorie, idSousCatégorie, nomTiers, compte
                    ) VALUES (
                        %(idMouvement)s, %(montant)s, %s, %s,
                        %(idCategorie)s, %(idSousCategorie)s, %(nomTiers)s, %(idCompte)s
                    )
                    ON DUPLICATE KEY UPDATE
                    montant = VALUES(montant),
                    date = VALUES(date),
                    type = VALUES(type)
                """, (temps_id, type_txt, row))
            
            self.dst_conn.commit()
            self._update_last_migration("Mouvement")

    def close(self):
        self.src_conn.close()
        self.dst_conn.close()

if __name__ == "__main__":
    migrator = Migrator()
    
    try:
        migrator.migrate_categories()
        migrator.migrate_comptes()
        migrator.migrate_transactions()
        
    finally:
        migrator.close()
    print("Migration incrémentielle terminée avec succès!")
