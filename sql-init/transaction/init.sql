create table if not exists Categorie
(
    idCategorie       int auto_increment
        primary key,
    nomCategorie      varchar(50)                           not null,
    dateHeureCreation timestamp default current_timestamp() null,
    dateHeureMAJ      timestamp default current_timestamp() not null
);

create table if not exists SousCategorie
(
    idSousCategorie   int auto_increment
        primary key,
    nomSousCategorie  varchar(50)                           not null,
    idCategorie       int                                   not null,
    dateHeureCreation timestamp default current_timestamp() not null,
    dateHeureMAJ      timestamp default current_timestamp() not null,
    constraint SousCategorie_Categorie_idCategorie_fk
        foreign key (idCategorie) references Categorie (idCategorie)
            on delete cascade
);

create table if not exists Utilisateur
(
    idUtilisateur     int auto_increment
        primary key,
    nomUtilisateur    varchar(50)                           not null,
    prenomUtilisateur varchar(50)                           not null,
    login             varchar(50)                           not null,
    mdp               varchar(200)                           null,
    hashcode          varchar(128)                          null,
    dateHeureCreation timestamp default current_timestamp() not null,
    dateHeureMAJ      timestamp default current_timestamp() null,
    ville             varchar(50)                           null,
    codePostal        char(5)                               null
);

create table if not exists Compte
(
    idCompte          int auto_increment
        primary key,
    descriptionCompte varchar(50)                           not null,
    nomBanque         varchar(50)                           not null,
    idUtilisateur     int                                   not null,
    dateHeureCreation timestamp default current_timestamp() not null,
    dateHeureMAJ      timestamp default current_timestamp() null,
    constraint Compte_Utilisateur_idUtilisateur_fk
        foreign key (idUtilisateur) references Utilisateur (idUtilisateur)
            on delete cascade
);

create table if not exists Tiers
(
    idTiers           int auto_increment
        primary key,
    nomTiers          varchar(50)                           not null,
    dateHeureCreation timestamp default current_timestamp() not null,
    dateHeureMAJ      timestamp default current_timestamp() not null,
    idUtilisateur     int       default 1                   not null,
    constraint Tiers_Utilisateur_idUtilisateur_fk
        foreign key (idUtilisateur) references Utilisateur (idUtilisateur)
);

create table if not exists Virement
(
    idVirement        int auto_increment
        primary key,
    idCompteDebit     int                                       not null,
    idCompteCredit    int                                       not null,
    montant           decimal(6, 2) default 0.00                not null,
    dateVirement      date          default curdate()           not null,
    dateHeureCreation timestamp     default current_timestamp() not null,
    dateHeureMAJ      timestamp     default current_timestamp() not null,
    idTiers           int                                       null,
    idCategorie       int                                       null,
    constraint Virement_Compte_idCompte_fk
        foreign key (idCompteDebit) references Compte (idCompte),
    constraint Virement_Compte_idCompte_fk_2
        foreign key (idCompteCredit) references Compte (idCompte)
);

create table if not exists Mouvement
(
    idMouvement       int auto_increment
        primary key,
    dateMouvement     date      default curdate()           not null,
    idCompte          int                                   not null,
    idTiers           int       default 1                   null,
    idCategorie       int       default 1                   null,
    idSousCategorie   int                                   null,
    idVirement        int                                   null,
    montant           decimal(6, 2)                         null,
    typeMouvement     char      default 'D'                 null,
    dateHeureCreation timestamp default current_timestamp() not null,
    dateHeureMAJ      timestamp default current_timestamp() not null,
    constraint Mouvement_Categorie_idCategorie_fk
        foreign key (idCategorie) references Categorie (idCategorie),
    constraint Mouvement_SousCategorie_idSousCategorie_fk
        foreign key (idSousCategorie) references SousCategorie (idSousCategorie)
            on update cascade on delete set null,
    constraint Mouvement_Tiers_idTiers_fk
        foreign key (idTiers) references Tiers (idTiers),
    constraint Mouvement_Virement_idVirement_fk
        foreign key (idVirement) references Virement (idVirement)
            on update cascade on delete set null
);

DROP TRIGGER IF EXISTS TRG_BEFORE_UPDATE_CATEGORIE;
DROP TRIGGER IF EXISTS TRG_BEFORE_UPDATE_SOUS_CATEGORIE;
DROP TRIGGER IF EXISTS TRG_BEFORE_UPDATE_TIERS;
DROP TRIGGER IF EXISTS TRG_BEFORE_UPDATE_UTILISATEUR;
DROP TRIGGER IF EXISTS TRG_BEFORE_INSERT_MOUVEMENT;
DROP TRIGGER IF EXISTS TRG_BEFORE_UPDATE_VIREMENT;
DROP TRIGGER IF EXISTS TRG_AFTER_INSERT;
DROP TRIGGER IF EXISTS TRG_AFTER_DELETE_VIREMENT;

DELIMITER $$
create trigger TRG_BEFORE_UPDATE_CATEGORIE
    before update
    on Categorie
    for each row
begin
    SET NEW.dateHeureMAJ = CURRENT_TIMESTAMP;
end;

$$

create trigger TRG_BEFORE_UPDATE_SOUS_CATEGORIE
    before update
    on SousCategorie
    for each row
begin
    SET NEW.dateHeureMAJ = CURRENT_TIMESTAMP;
end;

$$

create trigger TRG_BEFORE_UPDATE_COMPTE
    before update
    on Compte
    for each row
begin
    SET NEW.dateHeureMAJ = CURRENT_TIMESTAMP;
end;

$$

create trigger TRG_BEFORE_UPDATE_TIERS
    before update
    on Tiers
    for each row
begin
    SET NEW.dateHeureMAJ = CURRENT_TIMESTAMP;
end;

$$

create trigger TRG_BEFORE_UPDATE_UTILISATEUR
    before update
    on Utilisateur
    for each row
begin
    SET NEW.dateHeureMAJ = CURRENT_TIMESTAMP;
end;

$$

create trigger TRG_BEFORE_INSERT_MOUVEMENT
    before insert
    on Mouvement
    for each row
begin
    DEClARE v_Categorie INT DEFAULT 0;

    /* Il faut vérifier que la sous-catégorie appartient bien à la catégorie */
    IF NEW.idSousCategorie IS NOT NULL THEN
        SELECT idCategorie INTO v_Categorie FROM SousCategorie WHERE idSousCategorie = NEW.idSousCategorie;
        IF v_Categorie <> NEW.idCategorie THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La sous-catégorie n appartient pas à la catégorie choisie';
        end if;
    end if;
    SET NEW.dateHeureMAJ = CURRENT_TIMESTAMP;
end;

$$

create trigger TRG_BEFORE_UPDATE_VIREMENT
    before update
    on Virement
    for each row
begin
    SET NEW.dateHeureMAJ = CURRENT_TIMESTAMP;
end;

$$

create trigger TRG_AFTER_DELETE_VIREMENT
    after delete
    on Virement
    for each row
begin
    DELETE FROM Mouvement WHERE idVirement = OLD.idVirement;
end;

$$

create trigger TRG_AFTER_INSERT
    after insert
    on Virement
    for each row
begin
    /* Il faut insérer deux mouvements correspondant à ce virement inter-comptes */
/* un mouvement au débit sur le compte débité */
/* Un mouvement au crédit sur le cmpte crédité */
INSERT INTO Mouvement(idCompte,montant,typeMouvement,idVirement,dateMouvement) VALUES (NEW.idCompteDebit,(NEW.montant * -1),'D',NEW.idVirement,NEW.dateVirement);
INSERT INTO Mouvement(idCompte,montant,typeMouvement,idVirement,dateMouvement) VALUES ( NEW.idCompteCredit,NEW.montant, 'C',NEW.idVirement,NEW.dateVirement);
end;

$$

-- ===== UTILISATEUR =====
INSERT INTO Utilisateur (nomUtilisateur, prenomUtilisateur, login, mdp, ville, codePostal)
VALUES ('Martin', 'Pierre', 'pmartin', 'motdepassehashé', 'Lyon', '69001');

-- ===== CATéGORIES =====
INSERT INTO Categorie (nomCategorie) VALUES ('Alimentation');
INSERT INTO SousCategorie (idSousCategorie, nomSousCategorie, idCategorie) VALUES (1, 'Courses', 1);
INSERT INTO SousCategorie (idSousCategorie, nomSousCategorie, idCategorie) VALUES (2, 'Restaurant', 1);
INSERT INTO SousCategorie (idSousCategorie, nomSousCategorie, idCategorie) VALUES (3, 'Fast-food', 1);
INSERT INTO Categorie (nomCategorie) VALUES ('Transport');
INSERT INTO SousCategorie (idSousCategorie, nomSousCategorie, idCategorie) VALUES (4, 'Essence', 2);
INSERT INTO SousCategorie (idSousCategorie, nomSousCategorie, idCategorie) VALUES (5, 'Train', 2);
INSERT INTO SousCategorie (idSousCategorie, nomSousCategorie, idCategorie) VALUES (6, 'Avion', 2);
INSERT INTO Categorie (nomCategorie) VALUES ('Logement');
INSERT INTO SousCategorie (idSousCategorie, nomSousCategorie, idCategorie) VALUES (7, 'Loyer', 3);
INSERT INTO SousCategorie (idSousCategorie, nomSousCategorie, idCategorie) VALUES (8, 'électricité', 3);
INSERT INTO SousCategorie (idSousCategorie, nomSousCategorie, idCategorie) VALUES (9, 'Internet', 3);
INSERT INTO Categorie (nomCategorie) VALUES ('Loisirs');
INSERT INTO SousCategorie (idSousCategorie, nomSousCategorie, idCategorie) VALUES (10, 'Cinéma', 4);
INSERT INTO SousCategorie (idSousCategorie, nomSousCategorie, idCategorie) VALUES (11, 'Sport', 4);
INSERT INTO SousCategorie (idSousCategorie, nomSousCategorie, idCategorie) VALUES (12, 'Voyages', 4);
INSERT INTO Categorie (nomCategorie) VALUES ('Revenus');
INSERT INTO SousCategorie (idSousCategorie, nomSousCategorie, idCategorie) VALUES (13, 'Salaire', 5);
INSERT INTO SousCategorie (idSousCategorie, nomSousCategorie, idCategorie) VALUES (14, 'Dividendes', 5);
INSERT INTO SousCategorie (idSousCategorie, nomSousCategorie, idCategorie) VALUES (15, 'Vente', 5);

-- ===== COMPTES =====
INSERT INTO Compte (descriptionCompte, nomBanque, idUtilisateur)
VALUES ('Compte courant', 'BNP Paribas', 1);
INSERT INTO Compte (descriptionCompte, nomBanque, idUtilisateur)
VALUES ('Livret A', 'Crédit Agricole', 1);
INSERT INTO Compte (descriptionCompte, nomBanque, idUtilisateur)
VALUES ('PEA', 'Société Générale', 1);

-- ===== TIERS =====
INSERT INTO Tiers (nomTiers) VALUES ('Amazon');
INSERT INTO Tiers (nomTiers) VALUES ('EDF');
INSERT INTO Tiers (nomTiers) VALUES ('Carrefour');
INSERT INTO Tiers (nomTiers) VALUES ('SNCF');
INSERT INTO Tiers (nomTiers) VALUES ('Uber');
INSERT INTO Tiers (nomTiers) VALUES ('Netflix');
INSERT INTO Tiers (nomTiers) VALUES ('Total');
INSERT INTO Tiers (nomTiers) VALUES ('Apple');
INSERT INTO Tiers (nomTiers) VALUES ('Google');
INSERT INTO Tiers (nomTiers) VALUES ('Airbnb');

-- ===== VIREMENTS AVEC CATéGORIES =====
INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 795.85, '2019-04-18', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 739.3, '2017-12-06', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 992.51, '2021-03-15', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 900.06, '2022-10-31', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 362.3, '2023-03-03', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 435.15, '2019-06-12', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 641.76, '2021-05-04', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 687.49, '2020-06-26', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 510.85, '2018-11-19', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 39.52, '2018-11-14', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 565.03, '2019-01-27', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 978.3, '2025-12-12', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 585.78, '2023-12-07', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 869.55, '2015-08-18', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 406.69, '2021-08-17', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 923.8, '2021-09-14', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 897.87, '2015-08-02', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 518.22, '2017-03-12', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 469.49, '2021-07-07', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 639.1, '2018-03-16', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 911.27, '2015-05-12', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 151.54, '2022-09-17', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 445.33, '2025-11-03', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 932.34, '2019-04-13', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 615.05, '2016-02-24', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 730.09, '2017-07-04', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 492.53, '2015-07-03', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 681.2, '2020-11-20', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 40.8, '2023-11-03', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 335.49, '2022-06-18', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 534.16, '2021-12-15', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 21.73, '2024-08-04', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 246.64, '2016-04-28', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 136.79, '2018-12-21', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 256.04, '2023-04-03', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 860.31, '2024-07-12', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 571.04, '2023-08-14', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 275.9, '2015-06-21', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 208.92, '2023-05-31', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 579.03, '2020-11-07', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 888.46, '2022-04-22', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 781.76, '2023-07-11', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 581.51, '2024-08-10', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 451.55, '2019-06-24', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 382.18, '2020-04-25', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 630.14, '2016-11-30', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 40.21, '2016-03-29', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 815.8, '2018-08-20', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 422.04, '2021-01-29', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 932.85, '2018-02-07', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 865.62, '2021-10-04', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 879.15, '2016-01-06', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 86.79, '2015-06-25', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 668.45, '2016-04-29', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 143.0, '2022-06-06', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 660.51, '2023-03-25', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 206.53, '2023-08-06', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 89.42, '2025-06-16', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 328.15, '2015-03-21', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 492.83, '2017-09-27', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 775.57, '2023-04-25', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 330.41, '2023-12-11', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 157.39, '2017-05-06', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 906.57, '2017-07-14', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 72.04, '2016-10-26', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 820.18, '2025-01-02', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 899.33, '2023-04-10', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 172.78, '2024-09-05', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 587.99, '2019-03-07', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 13.76, '2015-09-02', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 26.8, '2015-01-17', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 156.03, '2016-02-11', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 164.14, '2019-03-21', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 210.28, '2015-03-28', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 705.18, '2020-10-16', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 414.05, '2019-08-19', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 90.3, '2017-09-23', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 264.74, '2023-05-16', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 696.17, '2016-05-03', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 243.14, '2021-06-21', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 45.16, '2021-08-03', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 47.05, '2016-05-15', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 609.3, '2020-08-28', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 131.36, '2023-10-01', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 306.34, '2016-09-25', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 98.93, '2017-09-12', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 228.16, '2018-03-14', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 318.51, '2016-02-04', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 826.26, '2021-01-05', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 841.4, '2020-06-10', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 250.41, '2023-10-31', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 303.22, '2023-04-25', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 724.98, '2022-10-19', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 579.24, '2022-12-28', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 895.34, '2023-10-29', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 349.55, '2017-10-26', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 174.75, '2024-09-10', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 407.34, '2018-12-05', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 171.45, '2015-03-07', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 721.61, '2016-10-23', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 36.36, '2024-11-09', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 280.57, '2018-09-13', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 396.46, '2018-04-23', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 575.52, '2024-06-22', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 778.46, '2018-04-04', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 160.53, '2021-05-19', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 138.69, '2020-06-30', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 101.28, '2019-04-12', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 559.76, '2015-05-16', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 14.26, '2023-02-03', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 221.58, '2016-07-23', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 451.13, '2022-03-18', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 882.6, '2020-03-31', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 35.34, '2024-10-28', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 858.71, '2016-01-05', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 134.76, '2016-03-08', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 559.34, '2016-08-18', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 648.52, '2024-09-29', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 328.36, '2017-08-30', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 75.06, '2022-06-03', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 588.17, '2024-04-10', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 276.76, '2024-05-23', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 440.81, '2017-08-23', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 806.82, '2022-10-15', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 31.02, '2019-02-15', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 992.89, '2024-01-31', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 296.97, '2021-08-03', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 282.01, '2022-05-17', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 47.13, '2021-07-05', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 608.1, '2022-02-21', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 114.35, '2023-03-22', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 233.62, '2025-07-28', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 369.81, '2024-09-04', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 519.7, '2024-10-27', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 550.76, '2018-06-21', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 334.31, '2025-06-21', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 399.77, '2024-05-01', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 961.47, '2019-07-05', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 986.13, '2015-02-06', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 936.39, '2023-08-30', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 35.21, '2015-05-11', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 983.39, '2025-07-10', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 216.68, '2020-07-03', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 870.83, '2024-02-06', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 669.99, '2017-04-25', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 373.55, '2016-10-10', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 178.7, '2018-01-05', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 427.91, '2022-12-24', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 209.04, '2024-03-03', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 47.22, '2016-09-24', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 690.4, '2022-04-14', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 251.51, '2020-10-15', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 279.37, '2020-06-30', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 106.17, '2020-08-20', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 384.09, '2025-01-20', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 806.12, '2015-09-29', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 94.57, '2022-10-20', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 211.19, '2022-07-03', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 359.06, '2017-08-19', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 301.43, '2020-03-18', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 59.65, '2020-09-08', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 481.93, '2017-07-22', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 355.8, '2020-07-31', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 815.6, '2015-01-04', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 23.62, '2023-01-07', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 47.53, '2021-12-20', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 508.09, '2025-01-14', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 175.01, '2016-08-09', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 841.68, '2018-11-17', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 427.51, '2017-07-29', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 200.69, '2021-12-31', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 92.13, '2017-01-08', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 146.08, '2025-03-05', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 14.45, '2016-03-16', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 231.93, '2017-06-10', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 528.82, '2025-03-04', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 520.71, '2016-10-28', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 939.34, '2016-05-15', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 152.18, '2022-01-12', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 328.02, '2016-05-31', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 635.81, '2021-12-31', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 889.23, '2019-05-30', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 797.86, '2023-02-15', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 613.98, '2020-10-04', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 590.76, '2023-02-06', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 493.42, '2015-08-29', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 616.55, '2022-02-01', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 223.83, '2021-08-28', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 282.14, '2017-01-25', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 680.09, '2018-07-14', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 386.7, '2019-02-11', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 33.51, '2015-09-19', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 610.57, '2025-11-26', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 285.87, '2022-03-06', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 357.67, '2025-07-18', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 634.08, '2015-05-25', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 243.25, '2025-04-30', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 628.08, '2015-10-12', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 716.56, '2016-04-11', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 749.76, '2023-01-30', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 244.94, '2020-07-26', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 326.71, '2023-01-08', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 972.9, '2019-02-03', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 884.09, '2021-09-24', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 299.46, '2019-01-11', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 872.07, '2019-05-24', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 129.34, '2019-08-18', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 509.24, '2024-05-10', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 963.79, '2015-01-08', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 896.55, '2020-07-19', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 829.51, '2019-07-29', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 831.31, '2020-07-03', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 119.36, '2020-04-27', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 153.23, '2017-06-01', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 38.68, '2023-01-01', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 587.8, '2020-01-20', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 733.4, '2021-09-30', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 193.45, '2016-10-30', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 693.52, '2019-04-16', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 997.3, '2022-11-01', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 125.24, '2020-01-23', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 814.75, '2020-07-08', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 716.94, '2023-07-23', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 325.28, '2023-09-13', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 249.33, '2022-09-03', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 205.55, '2015-06-23', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 450.32, '2019-02-18', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 699.39, '2025-06-16', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 652.66, '2018-01-19', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 25.48, '2020-07-24', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 164.13, '2016-03-20', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 539.25, '2019-05-21', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 342.09, '2019-11-14', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 223.21, '2019-11-13', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 234.45, '2018-05-08', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 154.16, '2020-12-20', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 831.68, '2018-05-08', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 785.79, '2025-08-10', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 596.12, '2021-04-30', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 540.93, '2025-05-03', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 547.93, '2022-12-06', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 527.26, '2018-12-03', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 19.32, '2020-01-12', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 150.12, '2020-04-09', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 36.08, '2023-07-03', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 605.12, '2025-09-07', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 131.29, '2015-07-01', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 141.34, '2018-11-04', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 487.39, '2023-12-08', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 366.36, '2021-08-01', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 473.8, '2025-03-25', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 94.41, '2022-05-26', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 525.58, '2020-03-20', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 189.05, '2015-02-04', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 754.97, '2023-05-30', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 221.56, '2024-09-23', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 736.33, '2025-03-17', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 749.54, '2024-01-22', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 10.97, '2022-06-16', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 511.3, '2016-09-26', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 809.2, '2020-03-09', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 598.7, '2019-04-08', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 649.25, '2024-05-05', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 787.82, '2019-06-02', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 272.87, '2021-02-13', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 968.47, '2021-07-03', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 658.53, '2024-08-27', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 750.23, '2022-12-09', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 733.7, '2016-04-15', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 772.07, '2023-02-03', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 223.39, '2022-03-12', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 875.03, '2016-10-21', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 112.95, '2022-07-05', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 23.99, '2020-05-19', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 502.43, '2020-04-11', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 627.55, '2025-03-21', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 684.83, '2015-12-14', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 479.08, '2017-04-26', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 199.52, '2023-08-24', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 799.86, '2016-09-07', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 957.8, '2021-11-24', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 301.96, '2021-11-23', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 932.83, '2023-09-22', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 531.37, '2023-09-28', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 684.41, '2022-01-03', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 395.16, '2015-08-15', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 155.74, '2017-01-09', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 837.13, '2016-08-11', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 580.21, '2024-06-09', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 345.76, '2023-08-09', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 571.85, '2019-06-12', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 686.61, '2020-07-20', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 638.17, '2020-11-25', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 646.45, '2015-09-17', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 957.46, '2024-03-17', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 777.06, '2015-08-01', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 295.45, '2021-10-27', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 725.1, '2024-03-20', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 887.43, '2015-07-22', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 845.5, '2025-11-27', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 767.64, '2021-06-20', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 297.36, '2015-07-03', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 963.04, '2015-04-18', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 478.19, '2021-07-06', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 511.95, '2018-06-09', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 522.38, '2017-04-07', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 94.99, '2025-04-08', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 153.98, '2016-04-05', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 704.33, '2021-03-09', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 46.85, '2022-07-19', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 624.2, '2016-02-25', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 40.64, '2020-03-12', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 336.71, '2019-04-22', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 275.64, '2017-05-11', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 256.24, '2016-02-28', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 59.83, '2024-07-14', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 298.26, '2022-10-12', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 279.45, '2017-05-18', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 449.66, '2017-05-12', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 838.79, '2017-03-09', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 75.63, '2019-08-10', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 888.11, '2023-05-09', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 723.0, '2020-11-14', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 442.25, '2025-09-18', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 856.34, '2017-11-08', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 44.21, '2020-06-02', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 354.16, '2016-12-30', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 136.83, '2016-01-31', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 457.73, '2015-01-16', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 482.12, '2022-05-17', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 436.62, '2015-11-22', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 466.93, '2023-07-09', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 873.06, '2018-05-15', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 528.06, '2017-07-10', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 726.92, '2023-09-15', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 783.42, '2022-04-11', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 825.31, '2025-06-28', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 764.25, '2015-07-18', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 459.92, '2018-08-14', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 52.69, '2022-10-16', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 417.46, '2018-05-26', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 212.02, '2015-08-25', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 725.36, '2025-10-26', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 751.77, '2017-09-13', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 626.92, '2017-11-18', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 40.34, '2018-12-30', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 798.21, '2023-10-02', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 627.02, '2017-06-26', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 160.39, '2016-06-01', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 825.63, '2024-04-30', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 269.53, '2021-10-27', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 18.32, '2019-12-31', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 879.12, '2016-03-05', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 714.76, '2023-03-29', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 578.52, '2022-12-15', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 696.14, '2017-11-08', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 198.51, '2020-03-06', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 754.5, '2016-01-22', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 618.52, '2023-04-08', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 76.32, '2021-02-03', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 413.06, '2017-09-29', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 44.79, '2015-06-03', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 134.29, '2015-05-28', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 960.17, '2023-10-18', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 661.29, '2016-03-27', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 159.41, '2024-01-28', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 789.49, '2018-08-18', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 457.85, '2021-12-12', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 640.26, '2016-02-25', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 75.15, '2022-10-25', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 278.52, '2018-10-27', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 680.73, '2018-06-15', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 825.98, '2022-07-12', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 892.06, '2024-10-22', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 18.71, '2016-01-07', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 249.09, '2019-07-22', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 866.18, '2020-10-10', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 762.62, '2024-02-13', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 156.97, '2016-08-12', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 662.5, '2022-04-29', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 754.16, '2021-05-23', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 656.11, '2015-02-11', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 742.38, '2015-07-08', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 973.13, '2025-05-27', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 459.62, '2023-03-06', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 125.27, '2020-11-20', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 693.24, '2015-01-21', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 973.88, '2023-07-05', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 705.29, '2018-08-04', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 65.73, '2018-05-18', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 889.19, '2025-01-17', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 779.03, '2022-06-21', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 768.88, '2022-02-23', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 857.01, '2016-01-21', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 344.7, '2025-04-11', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 108.9, '2018-03-31', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 604.79, '2017-03-02', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 824.34, '2020-08-06', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 94.19, '2018-01-19', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 849.99, '2024-09-25', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 527.14, '2024-02-13', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 906.11, '2015-08-02', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 306.21, '2024-01-11', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 957.73, '2018-05-17', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 972.81, '2023-02-05', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 198.78, '2016-11-23', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 335.42, '2020-09-22', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 834.52, '2024-11-10', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 599.7, '2025-01-21', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 304.86, '2024-03-13', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 34.72, '2020-05-31', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 487.13, '2024-09-03', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 994.94, '2015-07-14', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 664.33, '2024-12-17', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 931.33, '2023-12-23', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 271.67, '2025-07-17', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 364.75, '2021-05-30', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 278.43, '2016-10-17', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 791.19, '2024-10-19', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 39.51, '2015-09-19', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 969.11, '2023-07-11', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 449.54, '2025-03-06', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 177.76, '2022-10-27', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 234.06, '2022-01-17', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 559.21, '2019-12-24', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 891.84, '2020-11-17', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 44.95, '2018-07-14', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 714.78, '2018-11-07', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 65.36, '2020-03-30', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 736.27, '2024-07-20', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 899.98, '2017-03-30', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 846.13, '2025-05-25', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 921.3, '2023-03-06', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 656.6, '2019-03-27', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 528.38, '2015-08-25', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 400.91, '2023-08-12', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 870.76, '2020-04-28', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 531.46, '2021-07-14', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 525.07, '2022-08-16', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 401.02, '2016-03-20', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 969.68, '2025-06-21', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 320.85, '2024-10-01', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 962.02, '2022-08-09', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 243.28, '2019-02-04', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 474.73, '2016-08-18', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 741.23, '2020-06-12', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 909.11, '2022-10-03', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 637.09, '2019-11-29', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 269.03, '2024-02-05', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 855.02, '2025-07-27', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 314.46, '2017-08-11', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 513.76, '2022-12-21', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 352.78, '2024-05-18', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 843.79, '2016-03-19', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 836.41, '2020-12-29', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 386.12, '2025-04-05', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 601.72, '2017-11-24', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 386.12, '2024-06-15', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 11.72, '2019-04-16', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 993.78, '2021-11-20', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 207.97, '2017-02-03', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 706.91, '2020-05-10', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 25.87, '2019-07-05', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 489.95, '2021-03-12', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 668.64, '2025-08-21', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 250.39, '2015-04-02', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 68.83, '2019-05-23', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 853.69, '2021-08-21', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 33.9, '2017-05-04', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 825.07, '2018-03-04', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 763.87, '2020-04-10', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 444.21, '2025-06-01', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 827.52, '2017-06-01', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 981.96, '2016-12-28', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 353.94, '2016-05-28', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 820.44, '2024-08-31', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 378.17, '2015-11-14', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 523.12, '2024-05-12', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 604.98, '2022-07-25', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 209.13, '2024-08-08', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 433.39, '2020-06-03', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 252.03, '2022-02-15', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 247.11, '2020-05-27', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 615.46, '2024-06-11', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 93.78, '2020-08-18', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 793.71, '2017-08-08', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 645.43, '2018-06-28', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 404.17, '2025-06-27', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 940.76, '2019-10-09', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 617.49, '2024-08-05', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 414.43, '2023-08-24', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 478.93, '2017-05-23', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 357.86, '2016-11-15', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 587.97, '2016-10-03', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 185.46, '2021-11-21', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 397.86, '2022-07-04', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 501.89, '2017-10-31', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 586.72, '2021-05-21', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 319.06, '2019-08-27', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 416.22, '2019-12-02', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 119.66, '2017-04-07', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 617.24, '2016-12-12', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 748.06, '2018-02-01', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 666.06, '2024-10-30', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 575.83, '2015-09-09', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 890.59, '2025-06-02', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 240.16, '2019-01-03', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 701.23, '2025-04-06', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 952.18, '2017-11-13', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 817.66, '2020-10-06', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 231.56, '2019-01-11', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 859.64, '2017-09-18', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 433.24, '2025-04-20', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 871.32, '2023-04-20', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 587.54, '2018-09-30', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 28.86, '2018-05-05', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 693.99, '2021-08-14', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 162.87, '2024-03-30', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 688.56, '2025-04-27', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 592.85, '2018-10-30', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 154.84, '2017-06-14', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 85.62, '2020-06-30', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 107.84, '2024-04-14', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 125.65, '2015-11-01', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 109.68, '2020-11-28', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 381.12, '2021-08-23', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 616.97, '2020-06-12', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 210.91, '2023-09-08', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 880.29, '2020-02-10', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 434.7, '2024-10-18', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 883.05, '2021-02-20', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 570.8, '2019-03-02', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 257.03, '2018-10-15', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 448.82, '2018-11-27', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 724.68, '2025-02-19', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 514.76, '2021-07-10', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 895.97, '2023-05-31', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 470.97, '2015-04-19', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 597.4, '2021-05-29', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 108.78, '2023-01-24', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 989.43, '2022-09-11', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 386.86, '2025-06-03', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 798.64, '2015-06-28', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 914.89, '2022-12-16', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 724.73, '2019-10-31', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 164.98, '2025-05-15', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 593.09, '2025-01-16', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 372.79, '2020-04-27', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 163.02, '2022-12-03', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 401.42, '2015-06-03', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 741.02, '2015-07-17', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 848.96, '2021-09-08', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 893.68, '2016-12-22', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 695.41, '2015-03-24', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 120.82, '2017-03-28', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 402.77, '2016-07-18', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 230.14, '2023-09-30', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 505.85, '2020-03-30', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 271.9, '2019-07-17', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 342.31, '2022-04-20', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 994.08, '2015-04-01', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 211.07, '2019-02-01', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 268.2, '2020-04-16', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 584.06, '2018-08-28', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 430.46, '2020-06-03', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 911.44, '2025-10-14', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 136.69, '2022-06-14', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 19.65, '2023-04-11', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 250.88, '2017-03-12', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 15.36, '2018-09-06', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 88.18, '2016-10-21', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 272.57, '2023-03-18', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 508.48, '2025-05-13', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 122.29, '2025-04-23', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 84.82, '2015-03-26', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 493.39, '2015-09-28', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 786.13, '2021-10-21', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 400.88, '2019-04-10', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 234.6, '2020-01-16', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 839.02, '2022-06-07', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 162.06, '2017-06-28', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 691.08, '2024-03-02', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 326.7, '2017-05-02', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 527.79, '2025-11-07', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 34.66, '2016-08-08', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 973.2, '2024-03-31', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 85.1, '2022-01-19', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 24.08, '2015-07-25', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 905.95, '2020-12-11', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 963.67, '2025-09-28', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 536.96, '2024-04-07', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 840.86, '2023-04-16', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 29.09, '2015-07-02', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 727.9, '2017-06-22', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 368.51, '2021-09-06', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 591.94, '2023-12-03', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 231.03, '2022-02-09', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 923.95, '2018-10-02', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 372.12, '2024-07-30', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 982.74, '2025-09-16', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 533.84, '2020-09-12', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 128.26, '2022-04-14', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 860.17, '2017-05-26', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 657.19, '2018-04-16', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 247.87, '2016-06-26', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 495.51, '2025-08-01', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 97.64, '2017-02-25', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 770.08, '2016-03-04', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 783.71, '2018-06-02', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 222.74, '2021-09-05', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 590.89, '2015-11-05', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 734.76, '2016-04-19', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 399.36, '2023-03-08', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 801.07, '2023-04-13', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 612.86, '2024-06-10', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 863.48, '2017-02-12', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 301.92, '2015-08-13', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 179.44, '2018-11-05', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 35.78, '2015-10-27', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 204.24, '2019-11-24', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 408.7, '2023-07-05', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 957.6, '2018-08-04', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 460.43, '2024-01-01', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 672.15, '2016-07-25', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 534.19, '2018-09-26', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 413.65, '2015-11-18', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 382.51, '2018-06-27', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 74.17, '2022-01-31', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 882.73, '2024-01-17', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 306.62, '2015-05-04', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 347.19, '2022-08-11', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 318.86, '2018-06-06', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 419.5, '2020-09-03', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 648.37, '2025-08-16', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 219.95, '2020-05-07', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 412.59, '2022-11-08', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 966.28, '2022-07-30', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 784.4, '2018-11-16', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 872.37, '2017-01-07', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 550.08, '2016-03-13', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 681.32, '2015-07-21', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 25.37, '2019-10-30', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 594.85, '2018-05-11', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 140.26, '2018-08-31', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 898.04, '2025-12-12', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 391.02, '2023-07-08', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 483.22, '2023-10-04', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 423.9, '2018-01-23', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 233.41, '2025-06-07', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 770.11, '2018-09-22', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 482.81, '2022-05-09', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 706.6, '2017-12-08', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 946.98, '2018-10-04', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 989.03, '2021-01-21', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 784.37, '2024-05-23', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 100.98, '2023-01-14', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 459.38, '2015-05-10', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 153.82, '2018-12-23', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 871.99, '2017-11-14', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 891.2, '2015-12-14', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 703.33, '2025-06-12', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 759.4, '2025-08-22', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 403.48, '2022-12-13', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 722.85, '2019-09-25', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 124.75, '2023-07-22', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 769.76, '2024-08-25', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 339.78, '2016-10-04', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 638.37, '2019-10-08', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 15.55, '2019-05-01', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 793.24, '2019-01-26', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 243.71, '2022-09-22', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 998.22, '2020-08-11', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 643.8, '2025-07-17', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 513.97, '2023-02-26', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 270.28, '2024-08-31', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 899.56, '2019-02-18', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 93.96, '2024-09-02', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 771.04, '2016-01-26', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 186.32, '2023-11-18', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 196.27, '2021-05-14', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 623.82, '2017-02-02', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 476.8, '2016-12-28', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 29.6, '2020-12-07', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 934.28, '2018-03-13', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 743.91, '2022-01-29', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 790.88, '2024-03-19', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 489.31, '2021-05-05', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 218.91, '2015-11-02', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 253.02, '2015-03-30', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 363.29, '2024-04-09', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 546.18, '2018-09-18', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 408.23, '2019-10-17', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 447.87, '2020-12-13', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 867.44, '2015-10-08', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 820.29, '2025-09-11', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 166.29, '2018-10-25', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 241.03, '2016-12-26', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 302.77, '2023-06-08', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 41.33, '2022-08-28', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 484.56, '2017-02-02', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 98.68, '2025-01-04', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 984.42, '2017-01-26', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 514.85, '2021-04-21', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 923.29, '2021-09-27', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 24.17, '2018-03-18', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 577.59, '2018-01-04', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 378.24, '2021-10-07', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 447.55, '2015-11-12', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 818.85, '2025-05-14', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 912.63, '2018-07-31', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 402.95, '2024-08-24', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 651.38, '2021-05-01', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 947.06, '2025-05-13', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 759.27, '2018-12-17', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 526.89, '2017-04-14', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 595.31, '2020-10-26', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 381.92, '2019-12-09', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 472.29, '2017-11-02', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 494.21, '2017-10-30', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 799.68, '2018-11-08', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 307.06, '2019-06-25', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 446.1, '2019-01-07', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 913.26, '2020-10-25', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 882.1, '2015-06-18', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 818.71, '2021-09-05', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 400.33, '2023-12-15', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 537.99, '2024-07-08', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 696.08, '2018-11-14', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 516.7, '2023-11-14', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 227.34, '2019-03-02', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 486.64, '2024-08-29', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 503.28, '2018-07-25', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 256.61, '2024-09-21', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 597.59, '2025-02-21', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 765.99, '2015-12-06', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 387.86, '2015-02-26', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 624.75, '2016-04-20', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 682.23, '2024-11-26', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 81.61, '2021-06-15', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 722.17, '2018-08-06', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 858.48, '2019-07-03', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 391.96, '2015-02-25', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 604.67, '2024-04-14', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 576.42, '2018-02-13', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 767.35, '2015-12-27', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 192.64, '2019-12-17', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 92.19, '2024-05-30', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 200.11, '2024-06-28', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 556.93, '2017-05-16', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 737.39, '2020-11-13', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 982.27, '2020-10-12', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 147.58, '2023-12-31', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 122.95, '2015-08-27', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 620.51, '2023-08-25', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 224.94, '2025-02-11', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 969.88, '2018-10-21', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 437.06, '2015-01-02', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 571.08, '2017-02-26', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 413.58, '2023-02-20', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 879.79, '2016-05-15', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 406.92, '2021-10-13', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 784.19, '2024-05-13', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 318.23, '2025-08-15', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 848.03, '2020-05-11', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 365.17, '2019-03-11', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 611.88, '2017-08-12', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 422.51, '2024-10-30', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 284.34, '2025-12-19', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 882.52, '2020-05-16', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 208.07, '2020-09-15', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 563.33, '2020-09-11', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 98.69, '2017-06-13', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 610.95, '2023-06-29', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 989.56, '2020-11-28', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 571.74, '2017-07-12', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 872.12, '2016-11-17', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 295.53, '2019-08-15', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 554.93, '2021-02-05', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 386.63, '2020-12-31', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 507.16, '2019-04-02', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 608.94, '2018-03-23', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 132.0, '2017-09-03', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 856.72, '2017-08-01', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 111.92, '2021-06-06', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 583.62, '2017-12-07', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 590.36, '2018-07-18', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 180.01, '2023-02-12', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 717.63, '2017-06-07', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 438.46, '2019-09-17', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 992.57, '2025-06-08', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 539.25, '2016-08-02', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 120.75, '2018-09-18', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 326.33, '2023-11-08', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 916.37, '2025-11-01', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 367.53, '2018-04-24', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 887.53, '2015-09-01', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 737.46, '2019-03-12', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 849.06, '2015-11-02', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 985.67, '2022-11-26', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 87.62, '2024-06-23', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 17.52, '2015-10-15', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 885.85, '2016-10-18', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 248.61, '2021-11-25', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 956.63, '2019-11-26', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 777.03, '2022-11-05', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 487.04, '2017-05-15', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 469.74, '2024-09-18', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 190.49, '2016-06-04', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 162.39, '2021-12-01', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 911.59, '2021-09-07', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 275.31, '2025-03-14', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 329.37, '2021-06-19', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 577.6, '2023-03-05', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 788.45, '2018-12-27', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 242.54, '2017-06-16', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 17.52, '2023-03-01', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 81.54, '2016-03-14', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 12.77, '2023-08-02', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 531.69, '2016-08-18', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 740.38, '2023-11-02', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 219.58, '2020-08-29', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 539.77, '2025-09-07', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 320.49, '2017-11-04', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 27.29, '2020-06-17', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 233.03, '2015-07-30', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 994.87, '2019-01-02', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 878.28, '2025-11-07', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 879.19, '2025-05-13', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 398.35, '2017-06-12', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 635.11, '2020-02-17', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 538.82, '2018-11-30', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 431.73, '2022-03-31', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 643.97, '2024-09-22', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 757.09, '2023-11-10', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 191.36, '2017-10-24', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 974.25, '2016-04-17', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 398.82, '2023-08-06', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 894.58, '2022-07-07', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 932.21, '2017-01-21', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 90.89, '2016-06-24', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 655.46, '2024-03-09', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 181.81, '2020-09-19', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 298.94, '2021-06-06', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 312.0, '2025-06-13', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 563.63, '2018-05-15', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 130.84, '2019-02-26', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 392.73, '2016-01-22', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 263.54, '2017-05-22', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 424.65, '2016-11-18', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 118.38, '2025-07-23', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 115.74, '2024-09-30', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 828.47, '2021-04-14', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 522.03, '2024-04-27', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 419.64, '2021-03-24', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 85.05, '2017-04-16', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 590.04, '2021-06-20', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 484.45, '2017-10-27', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 325.86, '2020-02-08', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 864.43, '2021-01-26', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 860.69, '2023-08-14', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 542.7, '2020-05-13', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 837.6, '2020-01-02', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 789.84, '2020-06-27', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 124.18, '2017-09-25', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 568.26, '2015-03-09', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 698.39, '2021-05-09', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 266.76, '2024-10-19', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 307.4, '2020-02-04', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 316.54, '2018-12-29', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 10.55, '2022-11-01', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 630.52, '2016-12-04', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 500.75, '2019-11-07', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 756.55, '2024-05-25', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 743.56, '2020-02-09', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 156.33, '2025-07-27', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 442.98, '2015-02-21', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 904.81, '2020-05-08', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 318.66, '2016-07-17', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 16.73, '2025-10-18', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 27.37, '2024-08-03', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 171.29, '2025-10-19', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 312.7, '2016-01-18', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 291.68, '2025-06-19', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 174.92, '2016-05-25', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 822.74, '2015-12-11', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 728.2, '2025-06-16', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 605.71, '2019-08-17', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 155.53, '2021-02-04', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 774.44, '2015-04-20', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 822.06, '2017-07-07', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 599.35, '2024-03-05', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 815.45, '2022-12-29', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 54.0, '2020-03-09', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 902.77, '2020-05-22', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 473.49, '2019-07-30', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 460.62, '2023-07-20', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 518.21, '2022-01-24', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 268.09, '2023-07-01', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 711.24, '2015-10-15', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 68.16, '2022-12-17', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 769.53, '2023-05-17', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 145.26, '2024-10-26', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 101.89, '2022-08-06', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 30.72, '2019-02-25', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 646.54, '2018-07-19', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 866.16, '2021-01-17', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 738.71, '2020-02-16', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 472.74, '2018-11-28', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 581.25, '2021-01-10', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 184.67, '2021-06-16', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 588.47, '2025-01-31', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 468.14, '2020-03-31', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 448.86, '2022-09-21', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 852.35, '2015-11-16', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 228.58, '2021-10-31', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 27.54, '2019-07-01', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 688.89, '2017-04-26', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 470.79, '2020-03-07', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 927.48, '2020-09-05', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 391.3, '2019-09-08', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 224.14, '2025-08-02', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 514.72, '2021-06-23', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 11.77, '2025-05-21', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 874.53, '2019-01-30', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 518.92, '2024-12-07', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 964.84, '2025-01-14', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 267.37, '2023-03-29', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 139.25, '2023-01-23', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 986.2, '2020-11-09', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 903.07, '2016-01-02', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 124.93, '2022-12-06', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 763.53, '2018-10-14', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 920.07, '2019-05-13', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 368.66, '2015-07-24', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 677.66, '2020-08-12', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 61.29, '2023-04-21', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 414.91, '2024-04-07', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 790.35, '2022-04-01', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 82.22, '2023-12-18', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 827.21, '2024-06-22', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 195.57, '2018-11-09', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 298.44, '2022-08-12', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 147.44, '2016-03-19', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 589.74, '2022-08-08', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 582.78, '2018-02-20', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 855.85, '2020-09-26', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 632.25, '2024-11-22', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 262.41, '2024-03-23', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 674.63, '2023-12-19', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 135.35, '2025-03-04', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 624.25, '2019-05-19', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 223.38, '2025-05-15', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 900.47, '2015-11-30', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 592.21, '2025-04-26', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 736.01, '2020-09-12', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 679.41, '2024-09-12', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 144.57, '2022-02-12', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 607.8, '2023-02-06', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 575.69, '2017-01-16', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 54.93, '2021-07-17', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 4 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 906.26, '2021-12-23', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 858.56, '2016-11-26', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 742.35, '2022-01-07', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 913.32, '2025-09-25', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 886.38, '2016-07-18', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 625.97, '2017-03-20', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 6 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 872.77, '2020-02-20', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 13 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 882.43, '2015-10-09', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 991.0, '2023-06-12', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 958.12, '2024-08-10', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 874.59, '2024-07-22', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 998.63, '2015-12-07', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 68.43, '2025-10-10', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 85.79, '2024-12-23', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 68.34, '2025-12-15', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 381.12, '2022-05-29', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 285.57, '2022-07-02', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 3 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 877.4, '2018-09-15', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 906.96, '2023-10-23', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 423.54, '2017-07-05', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 891.91, '2023-03-22', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 318.71, '2018-08-04', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 8 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 273.93, '2025-03-23', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 12 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 138.93, '2022-07-13', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 494.5, '2024-06-22', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 9 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 996.43, '2021-06-12', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 716.12, '2015-05-27', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 21.98, '2016-09-13', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 684.39, '2019-07-12', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 2 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 308.94, '2024-08-13', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 3, 141.26, '2015-04-07', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 15 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 800.98, '2016-02-19', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 223.63, '2017-01-17', 2);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 2, 
    idSousCategorie = 5 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 428.44, '2025-08-22', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 3, 431.72, '2019-07-17', 1);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 1, 
    idSousCategorie = 1 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (1, 2, 540.1, '2018-04-14', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 68.58, '2017-06-14', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 11 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 2, 454.3, '2015-03-26', 3);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 3, 
    idSousCategorie = 7 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (3, 1, 868.39, '2025-07-27', 4);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 4, 
    idSousCategorie = 10 
WHERE idVirement = @virement_id;

INSERT INTO Virement (idCompteDebit, idCompteCredit, montant, dateVirement, idCategorie)
VALUES (2, 1, 273.16, '2025-09-25', 5);
SET @virement_id = LAST_INSERT_ID();
UPDATE Mouvement 
SET idCategorie = 5, 
    idSousCategorie = 14 
WHERE idVirement = @virement_id;

-- ===== MOUVEMENTS AVEC SOUS-CATéGORIES =====
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-12-27', 2, 1, 5, 15, -610.89, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-04-01', 1, 10, 3, 9, -370.47, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-09-03', 3, 5, 3, 7, -167.09, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-12-27', 1, 8, 2, 6, -381.48, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-03-05', 3, 1, 5, 13, -365.8, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-09-28', 1, 8, 3, 7, -277.13, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-08-07', 1, 10, 2, 4, -285.91, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-02-09', 1, 6, 5, 13, 754.6, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-07-30', 1, 1, 2, 4, -343.63, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-04-09', 2, 10, 2, 6, 563.65, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-09-10', 2, 8, 2, 4, -752.05, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-11-26', 1, 7, 4, 12, -703.23, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-09-15', 2, 2, 2, 4, -656.4, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-05-12', 1, 8, 1, 3, 366.22, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-04-11', 3, 6, 4, 10, 48.45, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-07-25', 3, 8, 2, 6, 344.52, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-10-13', 1, 2, 3, 9, 782.51, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-05-01', 1, 4, 2, 4, -248.35, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-07-28', 2, 3, 3, 8, 24.2, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-03-29', 3, 5, 5, 15, -225.14, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-02-18', 2, 7, 1, 2, -674.91, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-07-12', 3, 8, 4, 10, -434.28, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-01-01', 1, 1, 3, 8, 69.4, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-05-06', 2, 3, 1, 1, 36.98, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-05-07', 1, 5, 2, 6, 366.8, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-04-15', 1, 2, 2, 4, -320.21, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-12-13', 3, 2, 2, 4, 794.94, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-12-12', 3, 2, 5, 15, 527.16, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-07-13', 3, 2, 3, 7, -214.68, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-09-01', 3, 4, 4, 11, 762.5, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-05-26', 1, 2, 1, 2, -734.77, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-01-18', 2, 7, 5, 15, -333.15, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-06-16', 2, 10, 3, 8, -501.41, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-07-16', 2, 9, 3, 8, -455.3, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-11-11', 2, 9, 1, 2, -766.67, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-08-27', 3, 4, 1, 3, 317.17, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-11-01', 1, 7, 4, 11, 470.17, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-05-11', 2, 4, 3, 9, 575.19, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-08-27', 3, 5, 2, 6, 204.27, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-12-03', 1, 9, 1, 1, 135.59, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-01-24', 3, 7, 5, 15, 703.11, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-05-27', 2, 4, 3, 9, -503.14, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-12-10', 3, 5, 2, 4, 144.57, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-01-21', 2, 10, 4, 11, 527.28, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-10-20', 3, 3, 3, 7, 357.5, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-04-03', 1, 2, 1, 1, 683.13, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-08-24', 3, 2, 5, 13, -191.72, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-06-07', 1, 8, 2, 6, -492.38, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-01-26', 3, 4, 3, 9, 545.3, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-10-19', 1, 6, 3, 9, -183.29, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-09-13', 2, 6, 1, 1, -436.97, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-11-05', 1, 4, 3, 8, -755.29, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-06-12', 1, 8, 2, 5, -249.06, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-02-23', 1, 6, 2, 4, -645.55, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-09-22', 1, 1, 1, 2, -768.66, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-02-06', 1, 2, 2, 6, 430.96, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-02-15', 3, 4, 5, 14, 619.03, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-04-24', 1, 2, 4, 12, 194.46, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-01-22', 1, 4, 1, 3, 575.03, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-09-28', 2, 8, 1, 2, 200.9, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-10-08', 1, 4, 1, 1, 393.56, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-03-11', 3, 8, 2, 5, 203.02, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-09-04', 1, 3, 4, 11, 631.63, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-06-05', 3, 1, 2, 4, 706.99, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-07-29', 1, 10, 1, 2, 278.04, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-12-13', 1, 8, 2, 5, -7.9, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-10-25', 3, 4, 3, 9, -277.06, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-06-24', 1, 8, 2, 6, -487.87, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-03-06', 1, 5, 1, 2, 324.22, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-05-24', 2, 6, 4, 10, 391.49, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-04-01', 2, 5, 2, 5, 239.74, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-04-20', 1, 2, 3, 7, -641.39, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-12-11', 2, 4, 5, 15, -228.32, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-04-03', 3, 10, 2, 4, 543.79, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-08-28', 2, 4, 1, 3, 159.25, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-12-31', 2, 3, 4, 12, 658.08, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-01-14', 2, 5, 5, 15, 375.26, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-08-24', 2, 5, 1, 2, 646.21, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-10-03', 2, 9, 5, 14, 467.83, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-02-16', 1, 5, 1, 2, 644.43, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-01-12', 3, 1, 4, 10, -45.09, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-10-25', 1, 1, 4, 11, 664.12, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-08-21', 1, 6, 4, 11, 107.77, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-01-26', 1, 1, 5, 15, -19.01, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-12-03', 1, 8, 2, 4, 408.16, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-10-05', 3, 2, 5, 13, 560.69, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-02-23', 3, 4, 5, 14, -604.26, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-03-07', 2, 8, 3, 9, 394.77, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-12-24', 2, 10, 4, 12, 780.84, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-04-22', 1, 10, 2, 4, 673.51, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-04-01', 1, 8, 1, 1, 83.58, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-10-15', 2, 9, 4, 10, 688.22, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-03-24', 3, 1, 2, 4, 564.15, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-12-01', 2, 8, 4, 11, 53.28, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-11-29', 3, 6, 1, 1, 699.82, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-02-24', 3, 10, 5, 15, 556.35, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-08-27', 2, 9, 3, 7, 230.73, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-10-24', 1, 3, 4, 12, 31.27, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-11-23', 2, 1, 4, 11, -244.62, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-04-05', 3, 5, 2, 6, -555.66, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-01-28', 3, 7, 3, 8, 104.27, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-10-21', 2, 6, 5, 14, 151.38, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-03-23', 2, 3, 4, 11, -596.34, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-09-28', 1, 3, 1, 1, -115.37, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-05-25', 3, 8, 2, 5, -473.94, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-12-05', 1, 8, 4, 10, -131.14, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-03-25', 2, 7, 1, 2, 144.16, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-06-14', 2, 2, 2, 5, 489.52, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-04-17', 3, 9, 5, 15, -148.71, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-11-15', 3, 1, 3, 8, -333.95, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-01-11', 1, 1, 4, 10, -210.38, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-09-13', 1, 5, 1, 1, 190.92, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-03-20', 2, 10, 3, 9, -706.39, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-12-08', 1, 10, 1, 2, 475.9, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-05-09', 1, 2, 2, 4, -776.19, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-27', 2, 1, 5, 13, -215.78, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-02-08', 3, 4, 1, 1, -344.72, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-07-07', 1, 8, 2, 6, -724.08, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-10-19', 1, 5, 1, 3, -555.24, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-03-15', 2, 10, 5, 14, -259.89, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-11-26', 1, 1, 4, 12, -716.25, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-12-30', 1, 3, 2, 4, -689.99, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-07-08', 2, 5, 4, 11, -84.26, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-10-26', 1, 7, 5, 15, -422.96, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-01-09', 3, 6, 5, 13, -587.51, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-11-12', 1, 4, 1, 2, 113.23, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-06-15', 1, 3, 2, 4, 640.8, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-01-09', 2, 9, 3, 8, 162.22, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-01-17', 1, 4, 5, 14, -32.87, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-11-13', 3, 3, 3, 7, -158.92, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-11-07', 1, 4, 4, 12, 533.66, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-06-06', 3, 6, 2, 6, 653.2, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-04-11', 1, 5, 1, 1, 331.94, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-09-11', 3, 10, 5, 13, -371.67, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-09-10', 3, 4, 3, 9, -680.8, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-12-29', 2, 8, 2, 6, -151.28, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-05-09', 2, 4, 1, 2, -618.72, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-05-29', 3, 10, 3, 8, 662.72, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-04-17', 1, 2, 3, 8, -89.74, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-07-14', 3, 6, 4, 10, 564.01, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-05-16', 3, 4, 1, 3, 140.97, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-10-10', 1, 9, 1, 1, 552.23, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-11-05', 3, 7, 5, 13, -511.8, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-06-03', 2, 5, 2, 4, -583.62, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-03-04', 3, 10, 5, 14, -214.21, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-01-27', 2, 6, 4, 11, -239.31, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-04-09', 3, 2, 4, 10, -33.92, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-05-04', 2, 10, 3, 8, 604.58, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-12-24', 2, 4, 1, 3, 83.34, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-06-18', 1, 7, 1, 1, -57.98, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-03-09', 1, 9, 5, 15, -251.9, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-07-22', 1, 7, 5, 13, 12.36, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-10-18', 1, 4, 2, 4, 123.81, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-11-24', 1, 3, 5, 14, 480.59, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-09-14', 1, 7, 5, 15, 458.53, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-11-09', 1, 5, 4, 10, -610.03, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-04-10', 1, 5, 1, 1, -368.24, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-05-08', 1, 1, 4, 12, 250.89, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-07-31', 2, 8, 2, 4, 344.34, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-01-13', 1, 2, 4, 12, -539.9, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-04-14', 1, 5, 3, 7, -768.56, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-09-15', 2, 10, 5, 13, -298.67, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-10-10', 3, 6, 5, 13, 7.82, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-11-24', 1, 10, 1, 3, -260.35, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-11-27', 2, 4, 1, 3, -159.21, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-07-30', 2, 10, 2, 6, 588.09, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-04-16', 2, 3, 1, 3, -25.63, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-09-21', 2, 1, 2, 6, 176.62, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-02-18', 1, 10, 2, 6, 509.98, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-07-22', 3, 8, 1, 3, 192.66, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-09-28', 3, 4, 5, 13, -496.22, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-02-12', 1, 6, 4, 12, 262.78, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-09', 3, 10, 1, 3, 84.4, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-05-15', 2, 3, 2, 6, -456.76, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-05-08', 1, 3, 4, 12, -790.99, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-07-22', 1, 5, 5, 13, -460.64, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-11-10', 3, 8, 5, 13, 235.65, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-07-19', 3, 1, 3, 9, -567.19, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-03-26', 2, 10, 3, 7, 481.59, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-01-29', 1, 2, 1, 3, 243.26, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-08-12', 1, 3, 5, 13, -779.42, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-05-07', 1, 9, 1, 1, -589.39, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-11-10', 1, 2, 2, 4, -560.1, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-05-28', 1, 3, 2, 4, -40.34, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-11-15', 3, 9, 3, 7, 356.96, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-05-22', 3, 8, 4, 12, -13.35, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-04-02', 3, 1, 3, 7, 637.04, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-05-30', 1, 9, 5, 13, 757.1, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-02-11', 1, 6, 2, 6, -516.14, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-01-14', 3, 1, 3, 9, -167.31, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-11-19', 3, 7, 1, 3, -623.18, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-07-15', 2, 6, 1, 1, 39.39, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-03-03', 3, 6, 1, 2, 100.37, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-11-04', 1, 10, 4, 12, 523.62, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-10-07', 3, 7, 4, 11, 451.11, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-06-30', 3, 10, 4, 10, -185.51, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-05-16', 2, 4, 1, 1, -452.18, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-07-05', 1, 10, 5, 13, 205.93, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-03-12', 1, 5, 2, 5, -276.91, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-03-02', 1, 2, 5, 15, -600.99, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-03-15', 2, 7, 3, 8, 496.6, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-05-13', 2, 1, 5, 14, -5.02, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-05-02', 2, 5, 3, 9, 524.23, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-07-14', 1, 4, 3, 7, 560.88, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-07-02', 1, 1, 1, 3, 176.01, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-06-16', 3, 8, 2, 5, -339.74, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-09-23', 3, 2, 3, 8, 14.42, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-02-27', 1, 4, 1, 3, -433.42, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-12-25', 2, 1, 5, 15, 264.91, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-02-16', 3, 5, 1, 3, 775.7, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-07-16', 1, 1, 5, 14, 674.76, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-11-11', 2, 10, 1, 1, -637.16, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-03-06', 1, 8, 1, 2, -273.26, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-08-21', 2, 3, 5, 15, -492.22, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-10-25', 1, 2, 4, 11, 358.58, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-04-08', 1, 3, 3, 7, -152.13, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-08-14', 2, 8, 3, 9, 488.13, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-03-31', 3, 2, 3, 9, -507.32, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-05-15', 2, 6, 1, 2, -438.95, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-08-29', 1, 8, 5, 13, -362.78, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-11-20', 2, 8, 2, 5, 444.05, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-05-09', 2, 8, 2, 4, -624.08, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-11-09', 2, 5, 1, 2, 217.45, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-03-14', 1, 6, 3, 7, -106.22, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-11-19', 2, 2, 2, 5, -737.45, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-09-30', 2, 5, 3, 8, -239.5, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-12-20', 1, 4, 4, 12, -188.1, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-05-15', 3, 10, 3, 7, -130.68, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-07-31', 1, 7, 5, 15, 369.26, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-07-25', 2, 10, 5, 14, 283.46, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-10-10', 3, 10, 2, 6, -205.22, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-05-20', 3, 5, 4, 12, -80.01, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-10-12', 1, 4, 5, 15, 628.23, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-04-11', 1, 2, 3, 9, -645.5, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-03-12', 2, 5, 1, 2, 345.76, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-11-14', 3, 6, 3, 9, 156.66, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-03-12', 1, 5, 3, 7, -546.23, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-08-23', 1, 9, 1, 3, 590.97, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-04-20', 2, 9, 4, 12, 115.67, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-10-29', 2, 3, 1, 1, 788.83, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-08-01', 1, 7, 3, 8, 680.73, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-05-03', 3, 3, 2, 6, -376.02, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-04-15', 3, 10, 4, 11, 539.36, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-09-17', 1, 3, 1, 1, -582.55, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-08-17', 1, 7, 4, 12, -10.59, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-05-17', 3, 4, 5, 13, -123.56, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-09-25', 3, 5, 3, 7, 492.32, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-09-05', 1, 5, 5, 14, -132.33, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-05-13', 2, 1, 3, 9, 642.74, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-03-24', 2, 5, 5, 15, -193.63, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-08-12', 2, 5, 4, 11, 452.41, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-07-10', 3, 2, 3, 9, -31.4, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-02-18', 2, 10, 5, 13, 555.67, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-08-29', 2, 6, 1, 2, -411.64, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-08-18', 3, 5, 3, 7, 161.77, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-01-27', 2, 1, 3, 7, 204.64, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-10', 3, 5, 2, 6, -642.41, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-06-04', 3, 3, 1, 3, 408.4, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-08-23', 3, 7, 4, 10, 6.15, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-01-31', 3, 8, 4, 11, -773.86, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-03-05', 2, 6, 5, 13, 246.23, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-11-17', 2, 1, 3, 7, 215.8, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-12-09', 2, 1, 2, 4, 550.84, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-05-10', 1, 10, 5, 13, -66.36, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-08-18', 2, 2, 1, 2, -241.53, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-10-22', 2, 1, 1, 2, -190.97, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-09-03', 3, 10, 3, 8, -253.27, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-11-28', 2, 3, 1, 3, 733.89, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-02-17', 2, 7, 3, 9, 60.94, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-11-16', 1, 6, 1, 2, -134.19, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-04-27', 2, 4, 1, 3, 424.35, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-07-17', 1, 9, 5, 14, -660.82, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-08-04', 2, 3, 3, 8, -733.47, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-07-25', 1, 9, 1, 1, 472.48, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-09-29', 3, 6, 2, 5, 306.02, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-05-15', 2, 2, 3, 7, -369.72, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-11-20', 1, 10, 4, 11, 188.81, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-10-18', 1, 8, 5, 15, 215.97, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-08-20', 3, 2, 5, 15, 607.21, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-06-04', 3, 7, 4, 11, 569.11, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-10-20', 2, 8, 4, 10, 258.68, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-09-25', 2, 6, 5, 13, 553.92, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-12-11', 1, 4, 1, 3, -551.22, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-04-16', 3, 2, 4, 10, -744.12, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-02-19', 1, 8, 4, 12, -422.27, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-12-04', 3, 8, 3, 7, -107.47, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-04-14', 1, 3, 4, 11, -769.39, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-05-09', 2, 8, 4, 11, -344.35, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-07-08', 2, 4, 2, 5, -680.8, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-06-16', 1, 1, 5, 14, -290.09, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-02-20', 3, 9, 1, 3, 763.66, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-10-18', 1, 5, 1, 1, -626.01, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-09-30', 1, 4, 2, 5, 604.5, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-10-03', 3, 6, 1, 3, -149.63, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-05-04', 3, 10, 4, 10, 582.53, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-08-09', 2, 9, 3, 9, 788.12, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-09-02', 2, 3, 3, 9, -403.63, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-11-19', 1, 8, 3, 7, 20.18, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-10-25', 2, 3, 1, 1, 208.56, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-02-10', 1, 2, 2, 5, -610.12, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-10-29', 3, 1, 2, 4, -184.45, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-09-11', 1, 3, 4, 10, 651.99, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-01-08', 2, 8, 2, 4, -433.75, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-01-24', 1, 8, 2, 4, 612.21, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-08-06', 3, 4, 5, 14, -5.88, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-12-10', 1, 6, 2, 4, -243.07, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-03-20', 2, 5, 1, 2, 449.78, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-06-06', 2, 8, 3, 9, 575.44, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-03-26', 2, 6, 2, 6, 686.28, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-12-25', 1, 1, 5, 13, -62.35, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-02-26', 1, 7, 2, 5, -551.95, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-11-30', 2, 6, 1, 3, -33.98, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-04-07', 2, 1, 1, 2, -537.22, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-02-08', 1, 3, 2, 6, 223.43, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-10-04', 2, 5, 4, 11, -47.02, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-09-03', 2, 1, 3, 7, 358.95, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-05-14', 2, 1, 2, 4, 612.51, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-07-10', 1, 6, 3, 8, -573.27, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-05-18', 1, 9, 3, 7, 497.16, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-03-02', 2, 8, 3, 9, -621.85, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-02-18', 2, 3, 1, 3, -578.17, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-03-29', 2, 5, 5, 14, 797.77, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-07-17', 3, 7, 2, 4, -450.8, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-07-03', 3, 2, 2, 6, 94.53, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-11-01', 3, 3, 4, 11, 647.76, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-11-03', 1, 4, 2, 5, -697.04, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-12-26', 2, 2, 5, 13, 791.82, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-04-25', 1, 3, 1, 1, 191.02, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-04-21', 1, 10, 5, 14, -371.34, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-09-15', 1, 7, 1, 2, 599.78, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-11-21', 2, 5, 2, 4, 74.88, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-01-30', 2, 3, 3, 8, 615.91, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-02-02', 3, 7, 1, 2, 542.8, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-04-04', 3, 1, 4, 12, 62.38, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-02-05', 3, 9, 4, 10, -611.99, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-05-14', 1, 3, 2, 5, -690.96, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-03-16', 3, 10, 2, 5, -548.03, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-05-09', 1, 7, 3, 7, -264.64, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-01-28', 2, 10, 1, 1, -123.72, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-11-07', 1, 8, 5, 13, 543.37, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-12-28', 1, 8, 4, 11, 589.2, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-01-08', 3, 5, 3, 9, -405.56, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-11-29', 1, 4, 5, 15, -584.21, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-09-30', 2, 4, 1, 1, 723.45, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-07', 2, 8, 3, 8, 312.71, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-03-04', 1, 4, 4, 10, 757.03, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-07-21', 1, 10, 4, 11, 109.42, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-02-20', 1, 2, 1, 1, 618.84, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-04-27', 2, 10, 4, 12, -595.33, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-08-28', 1, 8, 4, 10, 283.81, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-11-29', 3, 7, 5, 14, -71.88, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-09-24', 2, 2, 4, 10, -170.26, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-05-29', 2, 8, 2, 4, -46.78, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-03-15', 1, 10, 3, 7, 103.47, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-05-15', 1, 10, 1, 3, -447.2, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-08-04', 2, 7, 3, 8, -488.66, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-04-29', 2, 5, 5, 13, -100.28, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-07-10', 3, 5, 4, 12, -44.95, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-23', 2, 9, 3, 9, 637.24, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-12-03', 3, 7, 2, 6, 475.89, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-03-03', 1, 4, 4, 12, -701.57, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-01-17', 3, 10, 3, 8, 36.89, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-10-03', 3, 5, 1, 1, -115.09, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-10-24', 3, 2, 4, 11, 327.35, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-03-06', 2, 3, 2, 5, 220.69, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-08-30', 1, 3, 2, 5, -61.89, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-05-18', 1, 9, 5, 14, 693.45, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-11-24', 2, 10, 4, 12, 718.52, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-09-18', 2, 2, 4, 10, 265.04, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-02-21', 2, 4, 1, 1, 507.31, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-12-25', 2, 7, 2, 6, 205.89, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-03-10', 3, 5, 3, 9, 539.26, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-06-08', 2, 8, 3, 7, 409.63, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-08-26', 1, 9, 5, 15, 189.59, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-11-21', 3, 2, 4, 11, -278.97, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-01-22', 3, 10, 5, 15, 620.11, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-04-09', 1, 3, 2, 4, 769.26, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-02-15', 1, 4, 3, 9, 737.96, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-07-06', 2, 2, 4, 11, 7.56, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-06-11', 2, 2, 5, 13, -52.86, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-12-06', 3, 1, 1, 3, -715.83, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-01-25', 2, 8, 4, 12, -408.78, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-10-28', 1, 1, 3, 8, -11.89, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-05-28', 2, 10, 2, 5, 218.29, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-01-09', 3, 3, 4, 12, 719.59, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-10-24', 3, 8, 1, 1, -73.67, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-01-08', 2, 3, 2, 6, 768.55, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-03-03', 3, 4, 4, 12, -406.33, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-02-23', 2, 5, 2, 4, 34.73, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-11-10', 1, 10, 3, 7, -30.09, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-07-15', 2, 4, 1, 3, -303.73, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-12-03', 3, 4, 3, 9, 273.32, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-06-04', 1, 3, 5, 13, -257.3, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-03-19', 1, 10, 4, 11, 427.91, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-08-29', 2, 5, 1, 2, -268.0, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-02-06', 1, 5, 1, 3, 372.92, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-06-17', 2, 10, 4, 11, 313.13, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-07-17', 1, 2, 2, 5, 204.93, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-11-13', 3, 5, 2, 5, 639.49, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-10-17', 1, 9, 4, 11, 125.28, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-02-02', 1, 9, 1, 1, 218.61, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-11-20', 1, 5, 3, 9, 380.75, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-03-11', 1, 5, 5, 13, -707.84, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-06-19', 3, 9, 5, 14, -49.48, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-09-05', 2, 3, 2, 6, -72.14, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-08-06', 2, 2, 4, 12, 293.25, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-11-16', 3, 9, 3, 8, 401.02, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-05-07', 3, 8, 3, 8, 138.27, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-06-14', 1, 10, 2, 4, -680.13, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-04-12', 3, 9, 5, 14, 244.33, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-07-11', 3, 5, 5, 14, 170.95, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-06-06', 1, 3, 3, 7, 161.74, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-04-28', 2, 10, 2, 5, -161.03, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-07-26', 3, 10, 5, 14, 163.56, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-01-17', 3, 2, 4, 10, -337.93, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-04-26', 1, 8, 3, 9, -564.61, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-08-08', 3, 3, 5, 14, 786.17, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-07-17', 3, 9, 5, 14, 301.52, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-10-22', 3, 10, 5, 15, 795.15, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-09-13', 3, 4, 4, 10, -511.02, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-09-08', 1, 8, 3, 7, 216.88, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-09-30', 1, 6, 5, 14, -499.97, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-01-19', 2, 4, 1, 3, -228.48, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-10-28', 3, 4, 3, 9, -549.85, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-02-26', 1, 4, 3, 9, -586.21, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-10-28', 2, 10, 1, 3, -318.34, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-07-26', 1, 8, 1, 1, 157.21, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-10-22', 2, 2, 2, 6, -733.77, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-08-31', 3, 8, 1, 3, 411.93, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-10-10', 2, 4, 4, 10, -5.47, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-11-13', 2, 9, 5, 14, -347.19, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-04-04', 1, 1, 2, 5, -283.6, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-03-30', 2, 2, 3, 9, 115.52, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-08-24', 2, 8, 3, 9, 116.65, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-12-06', 1, 6, 5, 15, -179.48, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-02-10', 3, 8, 3, 9, 253.45, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-07-15', 3, 4, 1, 1, -568.66, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-02-08', 3, 1, 5, 14, 66.19, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-01-09', 3, 9, 4, 11, 567.9, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-10-23', 2, 10, 2, 5, -251.5, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-03-14', 2, 8, 1, 2, 795.23, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-09-12', 3, 3, 4, 10, -526.17, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-10-04', 3, 8, 1, 3, -104.97, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-11-07', 2, 5, 5, 15, -683.32, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-08-06', 3, 10, 1, 2, -547.08, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-06-04', 2, 2, 5, 14, -100.85, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-05-18', 3, 9, 1, 1, -663.73, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-12-01', 1, 10, 3, 7, -332.28, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-05-10', 3, 6, 4, 12, -112.17, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-12-31', 2, 7, 5, 15, -624.08, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-05-02', 2, 9, 4, 11, -173.91, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-02-27', 3, 9, 5, 13, -606.16, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-04-05', 2, 8, 3, 8, 788.37, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-02-01', 1, 10, 5, 13, 114.39, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-06-13', 2, 4, 4, 12, 212.74, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-04-22', 2, 3, 1, 3, 112.62, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-12-08', 3, 3, 2, 6, -226.1, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-12-28', 3, 2, 4, 11, -577.97, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-10-20', 3, 1, 2, 6, 343.47, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-07-10', 3, 4, 3, 7, 52.76, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-04-29', 1, 4, 2, 6, 456.39, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-06-14', 3, 10, 3, 9, -673.59, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-05-02', 2, 7, 2, 6, 522.5, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-01-09', 3, 6, 5, 15, 105.7, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-08-07', 2, 8, 5, 14, 8.7, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-09-11', 1, 7, 1, 1, 271.89, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-09-02', 2, 10, 5, 15, -201.38, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-02-04', 1, 3, 2, 6, -641.3, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-05-13', 1, 4, 3, 8, -693.17, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-04-26', 2, 10, 4, 12, -146.95, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-09-22', 1, 6, 2, 4, -226.74, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-12-28', 1, 9, 3, 8, -123.29, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-07-15', 3, 8, 5, 14, -556.05, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-04-23', 2, 2, 5, 13, 480.25, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-06-07', 3, 7, 3, 7, -603.68, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-10-04', 3, 1, 3, 8, 767.96, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-12-21', 1, 9, 3, 8, -178.37, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-12-23', 1, 7, 2, 6, 316.28, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-07-24', 3, 6, 3, 7, 418.99, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-08-23', 2, 3, 4, 11, -440.49, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-12-10', 2, 1, 4, 12, 49.64, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-05-27', 1, 2, 5, 14, 375.4, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-02-09', 2, 2, 2, 6, -676.4, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-12-10', 1, 9, 2, 5, 566.87, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-06-18', 3, 3, 1, 2, 76.56, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-04-01', 1, 10, 1, 3, -330.52, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-03-11', 3, 9, 2, 4, -693.95, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-02-25', 3, 7, 2, 5, 420.42, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-01-01', 1, 7, 2, 4, -187.97, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-10-15', 1, 7, 3, 8, -461.01, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-06-27', 2, 10, 4, 11, 615.9, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-10-19', 2, 10, 1, 2, -348.47, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-09-19', 1, 1, 5, 13, 273.6, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-11-15', 2, 6, 4, 10, -193.43, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-02-02', 1, 2, 1, 1, -37.53, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-06-16', 2, 9, 3, 7, 358.39, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-11-24', 1, 5, 2, 5, -583.34, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-08-19', 3, 7, 3, 8, -89.58, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-02-18', 3, 6, 5, 13, -668.98, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-11-30', 3, 6, 3, 9, -126.7, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-07-06', 2, 3, 1, 2, 382.65, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-05-26', 2, 9, 4, 10, -195.66, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-01-22', 3, 3, 5, 15, -286.6, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-10-04', 2, 2, 1, 1, -377.12, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-06-13', 1, 7, 5, 13, 782.41, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-06-18', 3, 9, 1, 3, -254.46, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-12-24', 2, 5, 1, 1, 733.31, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-01-25', 3, 1, 2, 5, 566.3, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-11-26', 3, 10, 3, 7, -246.24, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-04-02', 1, 5, 5, 13, -717.62, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-06', 2, 4, 1, 1, -235.11, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-07-23', 1, 9, 5, 15, 577.83, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-08-01', 2, 10, 5, 13, -218.88, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-05-13', 3, 2, 3, 8, 798.2, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-11-23', 2, 10, 5, 13, 593.53, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-06-04', 3, 7, 2, 4, -14.08, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-06-30', 2, 9, 2, 5, 437.63, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-01-03', 1, 2, 5, 14, -357.01, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-06-02', 1, 5, 1, 3, 357.24, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-03-08', 2, 4, 2, 6, 643.47, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-08-23', 1, 5, 4, 10, 439.78, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-03-26', 1, 6, 4, 10, -120.48, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-06-04', 2, 3, 4, 10, 201.52, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-05-17', 2, 8, 5, 15, -324.32, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-02-28', 2, 8, 5, 14, 650.61, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-10-26', 2, 8, 1, 2, 606.49, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-06-23', 3, 3, 4, 11, -766.18, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-04-05', 2, 10, 1, 3, -116.0, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-12-19', 3, 8, 3, 8, 762.41, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-09-18', 3, 6, 1, 1, 527.6, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-08-27', 2, 3, 1, 1, -71.65, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-04-11', 3, 2, 2, 5, 36.71, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-06-01', 1, 10, 5, 13, 441.36, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-05-28', 3, 5, 5, 13, -468.78, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-12-05', 2, 8, 3, 8, 243.29, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-10-15', 1, 9, 4, 10, 758.46, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-10-21', 2, 4, 3, 9, -102.38, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-10-05', 2, 7, 3, 8, -350.18, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-05-25', 2, 2, 5, 14, 24.54, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-02-14', 2, 4, 3, 9, -242.22, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-02-07', 1, 7, 5, 14, 523.68, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-08-20', 3, 9, 5, 13, -270.99, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-04-19', 1, 6, 1, 3, -459.43, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-28', 3, 1, 4, 10, -19.01, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-01-06', 3, 9, 5, 14, -760.61, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-05-16', 2, 4, 2, 4, -118.48, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-04-13', 2, 2, 2, 4, 343.81, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-04-30', 2, 5, 5, 15, 512.15, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-03-15', 2, 2, 1, 2, -169.62, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-04-22', 2, 9, 1, 1, 750.98, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-03-20', 1, 7, 1, 1, 379.37, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-05-23', 2, 10, 3, 9, -484.11, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-01-01', 2, 9, 4, 12, 375.79, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-10-31', 3, 5, 5, 14, 412.78, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-09-22', 3, 1, 5, 15, 37.4, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-01-18', 2, 6, 5, 15, -571.52, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-08-22', 1, 6, 2, 5, -703.36, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-12-04', 1, 1, 2, 5, 400.28, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-10-12', 2, 1, 1, 3, 52.88, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-07-30', 2, 5, 2, 6, 45.24, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-01-14', 1, 1, 5, 13, -345.42, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-06-14', 2, 9, 4, 12, 103.36, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-04-28', 1, 4, 4, 12, 759.28, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-02-19', 1, 8, 1, 2, -376.33, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-05-23', 1, 7, 2, 6, 526.47, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-03-24', 1, 4, 4, 11, 266.82, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-04', 1, 1, 5, 15, 192.11, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-01-31', 3, 9, 1, 3, 175.66, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-06-17', 2, 7, 4, 12, 541.88, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-12-03', 2, 4, 2, 5, -211.34, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-10-12', 2, 5, 2, 5, -198.05, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-12-11', 2, 1, 2, 6, 171.53, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-07-30', 1, 3, 5, 15, 685.14, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-07-20', 1, 3, 2, 6, 221.17, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-12-01', 2, 7, 2, 6, 522.23, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-11-22', 3, 3, 2, 4, -510.64, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-12-04', 2, 9, 2, 4, 520.76, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-11-24', 2, 3, 1, 2, 121.7, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-03-20', 1, 8, 5, 14, -133.38, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-10-18', 2, 3, 4, 12, 258.66, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-01-01', 3, 8, 5, 13, -706.11, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-11-10', 1, 1, 1, 1, 421.11, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-03-23', 1, 9, 3, 9, 456.3, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-05-14', 2, 4, 5, 13, 113.43, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-09-27', 1, 8, 5, 13, 58.04, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-07-19', 1, 2, 2, 4, -388.19, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-04-27', 1, 2, 3, 7, 308.26, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-01-01', 1, 6, 5, 14, -568.95, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-06-28', 2, 1, 4, 12, -89.88, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-07-31', 2, 10, 3, 9, 130.13, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-01-24', 2, 9, 5, 13, 38.34, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-02-08', 2, 1, 2, 5, -207.4, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-02-19', 1, 3, 5, 15, 619.83, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-08-16', 1, 4, 1, 1, 726.48, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-06-04', 3, 9, 1, 3, 431.77, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-07-31', 1, 3, 5, 14, -48.92, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-03-31', 2, 7, 4, 10, -487.05, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-02-13', 3, 9, 5, 13, -260.93, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-12-21', 2, 8, 3, 7, 511.39, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-12-25', 3, 5, 4, 12, -390.07, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-05-21', 3, 5, 2, 4, -100.55, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-05-06', 2, 2, 1, 3, 340.64, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-08-08', 2, 4, 2, 5, -207.24, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-05-03', 2, 1, 4, 11, -599.68, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-08-07', 1, 7, 3, 7, -288.35, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-06-12', 2, 5, 4, 10, 695.87, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-05-28', 1, 1, 1, 2, -617.75, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-03-19', 3, 2, 1, 2, -359.26, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-06-19', 2, 3, 5, 14, -213.16, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-05-26', 1, 8, 5, 13, 738.0, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-04-11', 3, 3, 2, 6, 349.05, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-09-14', 3, 9, 1, 3, -254.86, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-02-10', 1, 8, 3, 7, -275.74, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-06-28', 2, 8, 3, 9, 236.28, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-12-21', 2, 1, 4, 12, -793.65, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-08-18', 2, 5, 1, 3, 725.63, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-12-16', 2, 6, 2, 6, -134.58, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-03-18', 2, 9, 2, 5, 510.01, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-06-20', 2, 1, 5, 15, 330.11, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-09-27', 2, 8, 4, 10, -338.76, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-02-18', 2, 1, 3, 8, 516.11, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-05-15', 1, 9, 1, 1, 595.7, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-07-08', 3, 5, 2, 5, -489.63, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-11-03', 3, 5, 3, 7, -581.3, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-04-30', 2, 4, 4, 12, 641.15, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-06-24', 1, 3, 1, 1, -488.66, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-12-14', 2, 8, 3, 9, -20.43, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-08-26', 2, 6, 4, 12, 754.09, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-04-01', 1, 4, 1, 1, -753.63, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-05-19', 2, 3, 3, 9, 659.04, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-06-24', 2, 7, 2, 4, 8.34, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-11-02', 2, 8, 4, 11, 14.11, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-07-19', 3, 4, 3, 7, -621.02, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-04-04', 1, 7, 2, 6, -6.27, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-06-16', 1, 10, 4, 10, 235.41, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-09-27', 2, 1, 5, 14, -783.71, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-07-03', 3, 4, 4, 10, -256.54, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-08-04', 1, 8, 2, 6, -532.55, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-06-16', 1, 2, 1, 1, 541.16, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-01-25', 3, 8, 5, 13, -696.84, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-06-07', 3, 10, 3, 8, 270.33, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-06-14', 1, 9, 1, 3, -345.19, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-02-18', 1, 9, 4, 11, 680.92, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-12-20', 1, 4, 5, 14, -7.03, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-04-11', 2, 9, 3, 9, -429.43, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-07-21', 1, 9, 5, 14, -465.01, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-10-02', 1, 9, 1, 1, -396.89, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-07-15', 2, 6, 2, 6, -449.59, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-07-29', 2, 1, 2, 5, 278.21, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-12-20', 2, 8, 1, 2, -753.61, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-02-17', 2, 8, 1, 3, -229.17, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-09-26', 1, 8, 2, 6, -188.87, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-08-22', 2, 3, 3, 9, 470.12, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-07-01', 3, 3, 5, 13, -571.9, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-05-29', 2, 7, 1, 2, 230.23, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-01-28', 2, 3, 3, 8, -532.75, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-12-27', 3, 2, 1, 1, -284.84, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-06-03', 3, 8, 5, 13, -16.28, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-11-17', 1, 6, 4, 12, -143.39, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-11-04', 1, 3, 5, 15, 707.96, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-01-20', 2, 8, 3, 9, -251.85, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-09-06', 2, 5, 3, 7, -245.6, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-12-01', 1, 8, 4, 11, 631.11, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-12-29', 1, 8, 2, 6, -66.71, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-02-02', 1, 9, 5, 14, -793.94, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-02-14', 3, 4, 4, 12, -147.77, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-01-21', 1, 9, 3, 7, 89.93, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-12-08', 1, 6, 1, 3, 429.47, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-06-05', 2, 8, 3, 8, 612.76, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-03-05', 2, 10, 1, 3, -429.71, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-04-11', 1, 2, 5, 15, -313.41, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-04-15', 2, 1, 5, 15, 277.05, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-06-10', 2, 6, 2, 6, -652.46, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-08-21', 2, 10, 3, 7, 120.47, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-09-02', 2, 6, 1, 1, 758.76, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-01-08', 1, 5, 4, 10, 115.86, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-12-09', 3, 1, 3, 7, 177.89, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-07-26', 2, 6, 2, 6, -380.64, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-06-04', 3, 2, 3, 7, 293.52, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-09-16', 2, 10, 4, 12, -160.86, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-05-30', 3, 7, 5, 15, -507.03, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-09-06', 2, 5, 1, 1, -664.92, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-10-21', 2, 4, 1, 1, 282.86, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-05', 1, 10, 2, 6, -786.72, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-09-10', 2, 4, 3, 8, -553.58, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-12-08', 3, 4, 1, 3, -90.66, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-12-18', 2, 7, 4, 11, 499.47, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-01-20', 1, 8, 2, 4, 536.0, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-06-22', 2, 7, 1, 2, -323.6, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-08-14', 3, 7, 5, 15, -636.08, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-12-14', 1, 8, 1, 1, -463.76, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-07-23', 1, 10, 1, 2, 570.48, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-02-25', 2, 9, 5, 14, -594.45, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-02-25', 3, 10, 5, 15, -764.68, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-03-18', 1, 9, 4, 12, 188.17, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-04-30', 2, 10, 3, 8, -461.12, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-10-22', 1, 3, 5, 15, -282.83, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-09-02', 1, 5, 1, 3, 280.24, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-04-08', 2, 9, 2, 6, 104.51, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-07-24', 3, 2, 4, 12, 224.46, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-10-24', 2, 9, 2, 4, -782.9, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-11-24', 1, 9, 2, 5, 165.12, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-02-12', 2, 5, 2, 6, -239.38, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-04-04', 1, 10, 5, 15, -503.06, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-02-29', 1, 6, 1, 3, 381.93, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-01-01', 1, 6, 5, 13, -167.0, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-04-07', 3, 8, 2, 4, -783.31, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-03-05', 1, 7, 3, 9, -333.22, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-07-28', 2, 8, 3, 8, 792.73, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-04-08', 3, 3, 2, 5, 677.82, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-05-04', 1, 7, 5, 13, -110.08, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-05-25', 3, 7, 3, 8, -595.01, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-05-29', 3, 3, 2, 4, -620.75, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-04-09', 1, 7, 2, 4, 685.96, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-07-09', 2, 2, 2, 6, 209.31, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-01-16', 2, 3, 2, 4, 707.15, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-03-06', 2, 10, 3, 9, 731.62, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-07-23', 3, 10, 5, 15, 87.66, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-03-31', 2, 2, 5, 13, -522.45, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-08-02', 1, 10, 4, 10, -692.4, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-10-09', 3, 2, 2, 4, -107.47, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-05-04', 2, 4, 2, 5, 600.85, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-09-04', 3, 9, 5, 14, 241.79, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-05-05', 1, 5, 2, 4, -280.76, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-09-16', 3, 8, 1, 1, 543.42, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-03-28', 1, 10, 5, 13, 41.06, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-04-13', 2, 2, 5, 13, 381.0, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-03-11', 3, 8, 3, 7, -599.97, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-01-29', 3, 5, 5, 13, -312.88, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-11-28', 2, 2, 2, 6, -760.82, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-12-21', 3, 3, 1, 3, -150.23, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-02-25', 2, 9, 3, 9, 320.65, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-05-05', 1, 7, 5, 15, 663.36, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-02-22', 3, 7, 1, 1, 271.71, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-10-11', 1, 10, 3, 7, 26.33, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-03-30', 2, 1, 1, 3, 112.37, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-12-11', 1, 4, 1, 3, -597.39, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-12-08', 1, 4, 4, 10, 175.37, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-03-30', 1, 9, 4, 10, -458.21, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-08-22', 2, 9, 5, 14, -261.93, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-12-07', 3, 10, 4, 12, -307.46, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-05-26', 3, 5, 3, 8, 175.95, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-09-11', 2, 10, 2, 5, -441.26, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-06-05', 3, 2, 1, 3, -368.67, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-06-17', 1, 2, 1, 1, 540.61, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-09-24', 3, 3, 1, 1, 27.1, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-29', 1, 10, 3, 8, -461.18, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-07-22', 2, 6, 4, 11, -787.15, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-03-05', 2, 3, 1, 2, -493.45, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-03-03', 3, 3, 4, 10, -664.93, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-11-29', 1, 9, 3, 8, 15.4, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-02-20', 1, 7, 4, 11, 194.37, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-10', 3, 2, 4, 12, 717.49, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-12-02', 1, 4, 3, 7, 481.31, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-21', 1, 6, 1, 3, 346.41, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-12-12', 2, 9, 4, 10, 446.05, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-10-31', 3, 8, 4, 11, -717.97, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-11-08', 1, 9, 5, 13, -452.17, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-05-23', 3, 10, 4, 10, 371.5, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-12-04', 3, 5, 1, 1, 298.85, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-03-18', 1, 4, 2, 4, -267.15, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-09-07', 1, 9, 3, 9, -322.12, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-11-07', 3, 9, 3, 8, -722.74, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-01-13', 3, 1, 1, 3, -388.19, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-06-12', 2, 7, 1, 3, 190.58, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-04-18', 3, 5, 5, 14, -756.59, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-10-29', 1, 4, 5, 14, -409.48, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-09-06', 1, 4, 5, 14, -420.61, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-07-18', 2, 8, 3, 7, 201.11, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-10-14', 1, 10, 2, 5, -719.49, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-05-03', 2, 10, 1, 1, -633.68, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-06-26', 3, 7, 5, 14, 264.54, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-12-15', 1, 9, 4, 12, 760.74, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-06-13', 1, 2, 2, 4, -197.62, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-12-16', 1, 4, 4, 12, -672.35, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-06-28', 1, 7, 5, 13, 795.23, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-06-12', 3, 7, 5, 14, -174.02, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-10-17', 3, 3, 1, 3, 549.91, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-03-13', 1, 2, 5, 15, -294.94, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-06-06', 2, 2, 2, 5, -542.14, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-01-05', 2, 7, 4, 11, -742.0, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-05-12', 3, 7, 4, 12, 736.36, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-03-05', 1, 9, 1, 2, -316.69, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-12-10', 3, 1, 1, 2, 6.11, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-08-07', 2, 6, 3, 7, -110.65, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-07-31', 3, 6, 5, 15, -652.02, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-10-22', 1, 6, 2, 6, -411.7, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-10-21', 2, 6, 4, 12, 460.02, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-05-05', 2, 3, 5, 14, -26.9, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-06-23', 2, 6, 2, 5, -733.51, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-02-21', 3, 2, 5, 14, -732.69, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-04-26', 1, 7, 2, 6, -624.93, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-01-28', 3, 6, 3, 9, -337.33, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-10-14', 1, 1, 3, 7, -505.2, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-01-07', 3, 2, 2, 6, 358.73, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-12-24', 1, 7, 1, 3, 314.19, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-07-26', 1, 2, 2, 6, 672.12, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-02-16', 3, 5, 1, 1, 500.0, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-05-03', 1, 7, 4, 10, -157.41, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-01-22', 3, 9, 4, 10, -177.58, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-04-03', 2, 3, 5, 14, -530.42, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-03-24', 1, 8, 1, 1, -287.13, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-09-18', 2, 10, 4, 12, -118.28, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-12-30', 1, 2, 3, 9, 366.86, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-12-21', 1, 3, 2, 5, -608.84, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-07-07', 3, 6, 1, 3, 708.5, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-02-23', 3, 2, 3, 8, 55.26, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-09-04', 1, 3, 2, 6, -618.17, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-04-08', 3, 8, 4, 12, -387.74, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-06-06', 1, 8, 5, 14, -187.79, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-06-07', 3, 9, 2, 5, 69.52, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-02-25', 3, 5, 3, 7, 361.87, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-09-22', 1, 5, 1, 3, -580.32, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-09-23', 3, 7, 2, 4, 437.23, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-11-14', 3, 9, 2, 5, -17.29, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-10-31', 1, 7, 1, 1, -34.74, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-11-14', 2, 7, 1, 1, -151.56, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-12-21', 3, 1, 4, 11, 700.33, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-02-12', 2, 8, 4, 10, 601.89, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-07-21', 3, 10, 1, 3, 140.91, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-09-24', 1, 3, 2, 6, 165.47, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-05-10', 2, 6, 5, 13, 385.25, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-03-14', 1, 8, 1, 3, 460.49, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-05-01', 3, 2, 1, 3, -352.64, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-11-20', 3, 6, 1, 2, -238.85, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-09-27', 2, 3, 1, 1, 231.84, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-08-11', 3, 4, 3, 8, -661.56, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-10', 3, 8, 3, 7, -649.25, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-02-08', 1, 6, 4, 10, -411.28, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-05-06', 3, 3, 5, 13, 120.94, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-10-26', 1, 5, 3, 8, 171.51, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-09-23', 2, 8, 3, 8, -418.1, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-10-04', 3, 6, 4, 10, -380.27, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-07-27', 1, 1, 2, 4, -61.03, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-12-02', 1, 4, 2, 4, 472.27, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-12-25', 2, 3, 3, 7, 656.25, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-05-16', 2, 3, 3, 8, 179.2, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-02-09', 2, 7, 1, 2, 602.64, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-06-30', 2, 1, 3, 7, 493.11, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-29', 3, 10, 1, 1, -164.69, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-07-10', 1, 10, 3, 7, -392.58, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-02-13', 3, 8, 5, 14, 179.86, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-27', 1, 1, 3, 9, -720.11, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-11-05', 3, 7, 3, 8, -208.81, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-03-12', 1, 4, 3, 9, 39.11, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-10-22', 3, 1, 5, 14, -100.54, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-09-27', 1, 4, 4, 12, 290.27, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-12-29', 2, 10, 2, 4, 453.27, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-02-12', 1, 7, 3, 9, -290.46, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-12-19', 2, 7, 1, 2, 590.41, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-07-08', 1, 9, 4, 10, 176.94, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-11-24', 1, 6, 1, 1, 501.38, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-08-09', 3, 7, 5, 13, 167.97, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-07-21', 1, 6, 5, 14, 722.01, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-02-04', 1, 6, 3, 8, -342.24, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-12-17', 2, 7, 4, 11, 688.58, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-12-14', 1, 3, 4, 10, 43.65, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-08-09', 3, 2, 2, 5, 272.99, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-07-02', 2, 4, 4, 10, 29.84, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-07-29', 2, 4, 2, 4, 20.52, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-07-02', 1, 5, 4, 12, -743.16, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-10-24', 3, 1, 2, 6, 171.35, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-02-25', 3, 2, 3, 9, 401.52, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-05-27', 3, 4, 1, 1, 638.35, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-05-06', 2, 6, 1, 2, 768.01, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-12-08', 2, 4, 2, 5, -559.92, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-01-01', 3, 6, 3, 9, 47.29, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-11-25', 2, 2, 1, 2, -307.38, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-08-17', 2, 6, 4, 12, -635.33, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-02-05', 1, 2, 2, 4, -32.01, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-02-02', 3, 2, 4, 12, -175.27, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-07-29', 1, 6, 5, 13, 630.45, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-10-22', 1, 10, 2, 4, 574.93, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-10-16', 1, 4, 5, 15, 671.95, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-01-30', 1, 3, 1, 2, 459.57, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-03-18', 1, 1, 1, 1, 776.1, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-08-17', 1, 5, 1, 3, 78.27, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-11-11', 2, 2, 2, 4, -595.13, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-06-07', 2, 8, 5, 14, 281.0, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-06-15', 1, 4, 4, 10, -214.33, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-01-24', 3, 7, 2, 6, -150.86, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-06-12', 3, 6, 5, 14, 700.56, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-10-17', 3, 5, 3, 7, -316.75, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-11-23', 2, 9, 5, 15, -467.42, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-06-18', 3, 4, 2, 6, -217.53, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-08-10', 3, 5, 1, 1, 271.21, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-04-23', 3, 1, 4, 10, 307.38, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-04-14', 1, 7, 5, 13, 469.28, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-06-16', 2, 1, 5, 15, 346.47, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-12-25', 1, 6, 4, 11, -299.66, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-05-19', 1, 1, 4, 11, -200.0, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-04-21', 3, 6, 1, 1, 280.44, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-01-13', 2, 5, 3, 8, -75.4, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-03-18', 3, 4, 4, 10, 134.48, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-10-22', 2, 10, 2, 4, 786.08, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-01-16', 3, 7, 5, 14, -209.54, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-02-26', 2, 6, 1, 2, -331.61, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-07-03', 2, 10, 5, 15, -385.02, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-07-24', 2, 2, 5, 14, 735.74, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-10-01', 1, 8, 2, 6, 479.75, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-09-11', 2, 5, 5, 13, -527.7, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-06-12', 1, 6, 5, 13, -723.44, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-10-11', 3, 9, 4, 12, -194.68, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-08-23', 2, 3, 2, 5, -233.94, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-03-23', 1, 7, 1, 3, 669.54, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-10-29', 2, 3, 2, 6, 386.8, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-09-28', 1, 2, 3, 7, -665.32, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-11-30', 3, 3, 1, 1, -682.91, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-05-05', 1, 4, 2, 6, 723.63, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-08-03', 1, 7, 4, 12, -286.56, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-11-01', 2, 9, 3, 7, -757.94, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-10-05', 1, 6, 5, 14, 449.71, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-12-14', 1, 6, 4, 10, -555.05, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-06-02', 2, 9, 5, 13, -229.72, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-06-24', 2, 10, 1, 1, 102.34, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-07-07', 1, 8, 3, 8, -403.96, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-02-15', 2, 2, 5, 15, -72.57, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-07-08', 2, 1, 3, 8, 369.39, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-10-16', 2, 1, 2, 5, -390.96, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-07-11', 2, 4, 5, 15, 590.72, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-12-29', 3, 6, 4, 10, 299.68, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-12-29', 1, 4, 2, 4, -159.33, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-10-27', 2, 5, 2, 4, -134.92, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-02-16', 3, 1, 2, 4, -505.56, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-04-09', 2, 7, 5, 15, 443.71, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-04-15', 3, 2, 2, 4, -277.78, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-12-19', 3, 8, 5, 14, 585.39, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-09-02', 3, 2, 3, 8, 421.11, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-01-27', 3, 9, 5, 13, 135.98, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-10-03', 2, 7, 4, 12, -503.3, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-08-07', 2, 8, 1, 3, -364.48, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-03-24', 1, 5, 1, 1, -624.89, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-07-10', 1, 9, 3, 7, 32.89, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-03-30', 2, 6, 5, 14, 466.5, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-12-06', 1, 4, 4, 11, 492.7, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-02-01', 1, 2, 3, 7, 196.59, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-01-09', 2, 6, 2, 6, 545.96, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-07-03', 1, 4, 1, 2, -781.98, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-05-02', 2, 10, 5, 13, 199.45, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-04-04', 3, 4, 2, 4, -732.39, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-01-09', 2, 4, 3, 7, -93.66, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-08-07', 2, 5, 2, 5, -59.48, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-07-14', 3, 8, 1, 3, -208.41, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-05-25', 2, 3, 5, 14, 748.63, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-09-21', 1, 8, 5, 14, 467.98, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-06-14', 3, 8, 5, 15, 9.13, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-11-08', 2, 3, 4, 10, -471.36, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-10-07', 2, 2, 1, 3, -26.91, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-06-21', 3, 5, 1, 1, 670.48, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-02-14', 1, 5, 3, 8, -110.17, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-01-21', 1, 4, 5, 13, -144.09, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-04-27', 3, 2, 1, 2, -490.48, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-01-22', 3, 7, 3, 9, 424.46, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-08-23', 3, 10, 3, 8, -624.13, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-07-15', 1, 10, 5, 14, 347.89, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-11-02', 3, 3, 1, 1, 247.35, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-10-14', 1, 10, 1, 3, 637.41, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-05-29', 1, 4, 5, 13, 694.63, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-03-31', 2, 3, 2, 5, 59.34, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-03-02', 1, 3, 3, 8, 350.9, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-05-11', 3, 8, 2, 4, -362.18, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-12-05', 3, 2, 5, 15, -657.05, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-08-03', 3, 3, 2, 6, -241.4, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-01-22', 2, 10, 3, 7, -63.57, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-12-05', 3, 4, 5, 13, 214.53, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-10-22', 1, 2, 2, 6, -72.38, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-05-01', 1, 7, 1, 2, -385.79, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-03-05', 2, 6, 1, 2, 729.04, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-04-25', 1, 8, 5, 14, 466.03, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-12-08', 1, 4, 2, 6, 162.67, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-02-08', 3, 6, 4, 12, -632.06, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-02-08', 3, 9, 3, 8, 249.38, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-04-28', 1, 2, 3, 7, -779.78, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-02-24', 3, 10, 4, 11, 183.86, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-04-09', 2, 3, 1, 3, -129.69, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-03-23', 2, 7, 3, 7, 186.61, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-09-23', 1, 8, 2, 6, 277.11, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-09-21', 2, 10, 5, 13, 90.51, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-04-23', 3, 8, 4, 10, 109.09, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-10-10', 1, 2, 3, 8, -461.42, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-02-12', 3, 9, 5, 14, -481.11, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-07-29', 2, 6, 2, 6, 758.88, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-02-25', 2, 3, 2, 6, 708.99, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-12-02', 1, 4, 1, 2, -520.02, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-05-18', 2, 9, 1, 1, -672.66, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-09-05', 2, 3, 4, 12, -5.68, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-12-05', 1, 4, 2, 6, 557.09, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-08-24', 2, 9, 4, 10, 348.02, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-02-02', 3, 2, 5, 13, -378.6, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-10-01', 3, 9, 4, 10, -527.46, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-04-10', 1, 3, 2, 6, -478.79, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-01-11', 2, 9, 4, 10, -428.8, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-07-15', 3, 7, 3, 8, -309.49, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-06-06', 2, 3, 1, 2, -665.62, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-03-08', 1, 3, 2, 6, -182.7, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-08-04', 3, 2, 5, 13, 546.65, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-04-25', 2, 2, 2, 5, 317.32, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-04-26', 2, 2, 2, 6, 322.99, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-09-09', 1, 2, 3, 7, -28.08, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-03-28', 2, 2, 3, 7, 258.12, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-06-29', 2, 6, 2, 4, -246.79, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-11-29', 2, 9, 3, 9, -302.81, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-01-19', 2, 1, 1, 1, 112.18, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-04-19', 1, 7, 4, 12, -26.33, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-05-24', 3, 4, 5, 14, 525.64, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-08-02', 3, 2, 2, 5, -406.74, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-12-11', 3, 2, 4, 12, 425.41, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-01-09', 2, 9, 1, 3, 248.29, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-15', 3, 10, 5, 15, 766.72, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-07-08', 1, 8, 4, 12, -292.08, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-06-18', 2, 10, 3, 8, 90.35, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-04-23', 3, 8, 2, 4, 206.65, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-04-30', 2, 7, 4, 11, -728.72, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-02-16', 3, 5, 4, 11, -173.14, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-07-01', 1, 9, 5, 14, 408.09, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-02-20', 2, 3, 3, 8, 792.25, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-11-09', 1, 6, 1, 3, 751.22, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-12-14', 3, 8, 3, 9, 244.25, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-04-18', 1, 8, 1, 3, 220.74, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-08-11', 1, 9, 5, 13, 402.97, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-07-13', 1, 3, 2, 5, 275.28, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-01-16', 3, 10, 1, 1, -153.8, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-07-18', 1, 1, 5, 15, -142.66, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-10-14', 2, 6, 1, 2, -133.71, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-06-20', 2, 8, 1, 1, 408.94, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-10-11', 3, 8, 2, 4, -403.42, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-05-13', 2, 1, 5, 13, -95.0, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-11-30', 1, 2, 2, 4, -469.15, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-03-17', 2, 5, 1, 1, 792.88, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-03-02', 3, 10, 2, 6, 613.79, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-12-30', 1, 6, 2, 6, -183.75, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-11-23', 1, 1, 2, 6, 726.82, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-09-03', 2, 7, 3, 9, 414.62, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-09', 2, 7, 2, 6, -639.42, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-01-28', 3, 8, 2, 6, -241.06, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-07-10', 1, 3, 1, 3, -26.12, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-02-01', 3, 3, 5, 13, 761.4, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-06-21', 1, 6, 3, 7, 540.16, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-02-13', 2, 2, 1, 3, -683.99, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-09-04', 3, 7, 4, 11, -642.12, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-11-04', 1, 6, 3, 7, 616.02, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-04-19', 3, 1, 3, 7, -312.67, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-06-13', 2, 6, 2, 4, 417.15, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-10-14', 3, 9, 3, 8, 384.81, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-09-02', 1, 6, 4, 10, 303.88, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-08-08', 1, 10, 1, 1, -48.5, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-04-30', 1, 1, 2, 6, 264.2, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-02-27', 1, 3, 2, 6, -636.44, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-11-16', 3, 2, 5, 13, -595.71, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-04-08', 1, 4, 4, 12, -256.03, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-02-27', 2, 2, 3, 9, -706.38, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-02-18', 2, 10, 5, 14, 344.6, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-09-24', 3, 8, 5, 15, -292.19, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-09-06', 1, 2, 3, 9, 353.83, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-11-28', 3, 9, 2, 6, 208.98, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-02-09', 3, 6, 3, 7, -455.64, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-09-22', 1, 10, 5, 14, 621.0, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-02-07', 3, 7, 5, 15, 753.12, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-03-19', 1, 7, 4, 10, 639.3, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-12-05', 3, 3, 1, 1, -622.9, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-03-24', 1, 1, 5, 14, 540.09, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-03-22', 1, 7, 5, 14, -467.79, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-07-29', 3, 3, 5, 14, 49.47, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-06-10', 2, 7, 1, 3, -460.03, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-09-16', 3, 8, 1, 1, 239.64, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-07-16', 2, 8, 4, 12, -102.84, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-02-08', 1, 3, 5, 13, 164.5, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-01-18', 2, 2, 3, 7, 471.85, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-01-08', 2, 2, 5, 14, 154.74, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-06-02', 1, 8, 5, 13, 424.49, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-01-21', 2, 4, 1, 1, 567.73, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-06-25', 3, 6, 2, 6, 797.04, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-10-03', 2, 3, 5, 13, -533.32, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-07-13', 3, 8, 5, 15, -493.23, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-02-07', 2, 6, 2, 4, 738.74, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-12-23', 3, 10, 3, 9, 22.69, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-02-09', 1, 10, 1, 2, 696.35, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-06-10', 1, 8, 1, 2, 107.61, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-11-18', 2, 2, 1, 2, -790.17, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-09-21', 3, 1, 1, 2, 474.94, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-09-25', 1, 6, 2, 4, -295.33, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-07-28', 3, 4, 3, 9, -172.37, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-02-28', 2, 6, 4, 10, 217.29, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-08-11', 2, 2, 4, 12, -588.92, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-01-23', 3, 8, 1, 3, -630.81, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-09-15', 2, 1, 3, 8, 452.42, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-07-02', 1, 4, 2, 5, 424.17, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-04-11', 1, 6, 5, 13, -526.85, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-06-21', 3, 2, 2, 5, -71.55, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-05-09', 2, 2, 4, 12, 345.4, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-08-03', 3, 7, 1, 1, -786.49, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-06-03', 2, 9, 1, 1, 516.46, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-08-20', 1, 9, 1, 1, 204.66, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-06-08', 2, 10, 4, 12, -77.48, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-12-05', 1, 4, 5, 14, 753.86, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-01-17', 1, 7, 4, 10, 540.39, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-08-30', 2, 1, 3, 9, 665.69, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-10-04', 1, 1, 3, 9, 257.71, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-05-07', 3, 8, 5, 14, -78.32, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-07-20', 3, 9, 1, 2, -713.64, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-02-10', 1, 2, 5, 15, 446.46, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-06-28', 2, 10, 1, 3, 127.8, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-06-12', 3, 2, 1, 2, -627.73, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-10-01', 3, 3, 2, 4, -29.13, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-11-20', 3, 10, 5, 15, 336.2, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-12-08', 3, 6, 4, 10, 46.45, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-01-05', 3, 4, 4, 10, -214.36, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-04-19', 2, 4, 1, 2, 417.22, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-10-05', 1, 8, 5, 14, 309.14, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-09-19', 3, 1, 2, 5, 487.56, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-08-21', 1, 6, 3, 7, 367.28, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-12-18', 3, 8, 5, 14, -293.82, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-12-09', 3, 1, 2, 5, -641.02, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-10-16', 2, 9, 3, 9, 81.63, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-11-12', 3, 9, 1, 1, 338.23, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-04-14', 1, 7, 4, 12, -152.83, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-12-08', 3, 5, 1, 3, -632.52, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-09-08', 3, 8, 4, 11, 284.4, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-07-10', 3, 7, 4, 11, -11.1, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-09-21', 2, 9, 5, 13, 237.96, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-03-24', 3, 3, 2, 6, 747.02, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-06-23', 2, 2, 1, 3, 710.34, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-05-06', 3, 5, 1, 2, 476.53, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-04-29', 1, 3, 3, 7, 201.96, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-06-11', 2, 5, 4, 10, -472.67, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-09-14', 3, 1, 5, 14, 446.83, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-03-20', 2, 1, 5, 15, -316.78, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-07-08', 3, 7, 3, 9, -213.97, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-04-13', 2, 4, 4, 12, 417.69, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-10-04', 2, 7, 4, 12, 302.06, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-02-15', 3, 4, 5, 15, 136.81, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-03-01', 3, 5, 3, 9, 717.04, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-04-05', 1, 2, 2, 4, 315.04, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-07-06', 3, 5, 4, 12, -685.18, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-08-13', 3, 5, 4, 11, -113.25, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-09-01', 2, 7, 3, 7, -748.33, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-08-16', 2, 7, 5, 14, -573.59, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-04-23', 3, 5, 3, 7, 222.08, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-08-25', 1, 2, 1, 2, -182.5, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-11-19', 1, 2, 5, 15, -516.2, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-03-29', 2, 8, 4, 10, 233.21, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-04-26', 3, 5, 5, 14, 26.84, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-05-07', 3, 8, 4, 11, -301.54, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-12-17', 1, 5, 3, 8, -235.83, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-06-12', 2, 1, 5, 15, 187.57, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-07-05', 3, 4, 2, 4, -666.45, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-12-18', 3, 1, 3, 7, -480.19, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-07-10', 3, 10, 3, 9, -268.93, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-09-25', 1, 6, 2, 5, 246.37, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-06-14', 1, 4, 1, 2, -112.28, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-06-12', 1, 6, 1, 2, -414.28, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-02-11', 1, 9, 3, 7, 207.86, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-11-08', 2, 2, 5, 13, 467.18, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-01-05', 3, 9, 4, 11, -148.72, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-09-10', 2, 6, 5, 13, 280.69, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-01-05', 2, 3, 2, 4, -329.79, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-02-04', 2, 9, 5, 15, 146.59, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-08-04', 2, 7, 1, 1, -340.36, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-02-06', 1, 6, 3, 9, 96.95, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-03-25', 3, 8, 4, 10, 69.37, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-09-01', 1, 6, 2, 4, -87.86, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-07-14', 2, 8, 3, 9, 218.98, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-09-23', 3, 3, 5, 15, 266.92, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-04-03', 3, 4, 4, 11, 324.8, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-06-22', 3, 9, 1, 3, -35.56, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-04-11', 3, 3, 1, 2, 111.74, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-01-06', 3, 3, 1, 2, 86.26, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-11-24', 3, 5, 5, 14, -416.31, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-07-28', 1, 6, 5, 14, 566.28, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-04-17', 1, 2, 4, 10, 180.48, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-10-13', 3, 10, 4, 11, -88.65, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-06-05', 1, 8, 5, 13, 402.22, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-12-31', 1, 1, 3, 9, -57.14, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-05-28', 3, 2, 1, 2, -361.55, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-08-04', 3, 10, 1, 1, 606.95, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-03-20', 1, 3, 3, 9, -635.78, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-12-23', 2, 10, 4, 12, -684.66, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-08-18', 2, 4, 4, 11, -13.41, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-03-22', 3, 5, 4, 11, 422.54, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-06-05', 1, 1, 4, 10, -96.97, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-06-19', 2, 1, 5, 13, -158.43, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-11-25', 3, 1, 4, 11, -634.96, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-03-27', 1, 1, 5, 15, 775.89, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-07-06', 2, 6, 4, 12, -315.11, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-12-05', 2, 9, 3, 9, -657.76, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-05-30', 3, 7, 2, 5, 677.72, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-10-17', 2, 4, 2, 5, 681.81, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-07-14', 3, 6, 4, 10, -108.35, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-11-10', 2, 8, 4, 10, 171.77, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-04-12', 1, 4, 2, 6, -755.28, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-04-24', 3, 2, 1, 1, 620.63, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-09-13', 3, 4, 4, 11, 259.94, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-05-29', 3, 9, 1, 3, 420.87, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-06-26', 1, 1, 1, 2, -730.35, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-23', 2, 6, 1, 2, -46.69, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-02-15', 3, 1, 2, 6, 184.02, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-07-10', 3, 7, 5, 13, -380.61, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-05-30', 3, 8, 2, 5, 570.87, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-03-31', 3, 4, 2, 4, 643.58, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-11-16', 3, 8, 1, 2, -281.06, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-13', 1, 10, 5, 13, -473.84, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-03-04', 2, 9, 2, 4, 381.55, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-10-31', 1, 4, 4, 10, -561.71, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-07-30', 3, 5, 5, 15, -116.27, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-03-19', 1, 2, 5, 13, -587.46, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-04-13', 3, 7, 2, 5, -205.81, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-12-28', 1, 7, 4, 10, 686.87, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-12-05', 1, 1, 5, 15, 251.19, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-07-30', 1, 7, 5, 14, 335.6, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-02-15', 3, 8, 5, 15, -511.13, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-01-07', 3, 4, 2, 5, -769.42, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-02-22', 1, 10, 1, 2, -405.96, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-01-17', 3, 9, 3, 7, 167.94, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-03-19', 1, 1, 2, 6, 69.01, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-02-26', 2, 1, 4, 11, -532.17, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-12-31', 3, 5, 5, 14, -45.99, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-07-31', 1, 9, 5, 13, 122.24, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-02-28', 1, 8, 1, 2, -111.69, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-02-04', 3, 5, 2, 6, -83.3, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-09-19', 1, 2, 5, 13, -145.01, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-05-08', 3, 7, 2, 5, 17.02, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-03-23', 2, 7, 4, 11, 766.6, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-12-13', 2, 7, 2, 5, -680.47, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-03-08', 2, 7, 3, 7, 690.89, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-06-02', 1, 7, 1, 2, -505.64, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-02-17', 3, 5, 5, 15, -343.66, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-09-04', 1, 2, 3, 9, -356.15, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-03-31', 2, 9, 4, 10, 291.82, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-05-29', 3, 4, 4, 12, 536.37, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-03-19', 3, 3, 3, 8, -789.1, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-02-26', 1, 3, 2, 5, -303.64, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-12-25', 2, 7, 3, 8, -710.18, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-06-03', 2, 9, 5, 14, 414.2, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-05-12', 2, 7, 1, 1, -464.24, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-04-16', 2, 2, 2, 6, 193.33, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-03-15', 1, 3, 3, 8, -83.41, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-10-11', 2, 10, 2, 5, 755.18, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-12-06', 2, 7, 5, 13, 65.01, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-06-16', 3, 1, 5, 14, -431.89, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-02-12', 1, 7, 3, 9, -237.84, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-02-06', 2, 9, 5, 13, 640.98, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-04-03', 2, 10, 2, 4, -119.03, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-07-09', 2, 3, 1, 2, 186.52, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-08-15', 2, 4, 4, 12, 279.94, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-02-11', 1, 8, 4, 12, -354.53, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-03-16', 2, 2, 3, 8, -422.83, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-10-27', 3, 1, 1, 1, -612.51, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-07-12', 3, 4, 3, 8, 647.44, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-02-04', 1, 2, 4, 10, 451.39, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-10-05', 2, 2, 1, 3, -715.96, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-03-31', 1, 2, 3, 9, -551.4, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-04-03', 1, 4, 4, 12, -567.04, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-07-01', 1, 9, 5, 14, 358.24, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-03-30', 1, 7, 1, 1, 492.83, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-01-01', 3, 10, 4, 12, 642.73, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-02-22', 1, 8, 4, 11, 280.19, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-11-16', 3, 4, 3, 9, -544.74, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-01-28', 1, 2, 4, 11, 791.31, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-04-20', 1, 7, 5, 15, 11.24, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-04-07', 2, 2, 1, 2, -480.66, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-04-27', 1, 8, 5, 15, -122.8, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-02-13', 1, 1, 3, 7, 460.96, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-11-27', 2, 7, 4, 10, 524.32, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-10-11', 2, 5, 4, 12, -416.73, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-12-05', 2, 3, 3, 7, -93.88, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-03-27', 3, 4, 5, 14, -310.25, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-04-12', 2, 1, 4, 10, 193.29, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-10-31', 3, 5, 5, 14, -251.63, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-02-06', 3, 6, 1, 3, 15.16, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-08-05', 2, 5, 4, 10, 179.07, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-11-25', 2, 9, 4, 10, 557.57, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-03-30', 1, 2, 3, 7, -232.76, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-10-01', 2, 4, 3, 8, -650.43, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-03-14', 3, 3, 1, 2, 142.96, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-01-29', 1, 10, 5, 15, 154.34, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-04-17', 1, 9, 1, 2, 446.45, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-12-05', 1, 9, 1, 1, -541.57, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-12-26', 1, 10, 1, 2, -619.01, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-03-10', 1, 7, 4, 10, -685.92, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-09-13', 2, 10, 4, 11, -603.7, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-01-19', 2, 2, 4, 11, 513.38, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-03-26', 1, 4, 2, 5, -775.4, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-04-19', 2, 4, 5, 13, 446.85, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-05-23', 1, 6, 1, 2, -454.41, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-07-08', 3, 6, 2, 4, -706.48, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-01-09', 1, 3, 2, 5, 338.79, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-06-14', 1, 8, 2, 5, 56.79, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-01-11', 1, 4, 3, 7, -174.97, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-01-28', 3, 7, 5, 13, -732.41, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-12-04', 2, 6, 3, 8, -707.89, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-08-24', 1, 2, 2, 4, -232.0, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-05-12', 1, 1, 2, 5, -358.45, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-02-26', 3, 10, 4, 12, -791.77, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-11-01', 1, 6, 5, 15, -661.98, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-01-23', 1, 6, 4, 10, -80.79, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-02-14', 3, 1, 1, 2, -142.3, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-10-29', 1, 5, 1, 1, -318.23, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-06-20', 1, 8, 2, 5, 101.82, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-07-07', 3, 5, 3, 8, -82.78, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-06-21', 2, 10, 2, 6, 778.69, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-04-16', 2, 8, 4, 11, -243.46, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-04-25', 3, 10, 2, 5, 282.21, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-07-08', 2, 2, 4, 10, 107.46, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-11-27', 2, 2, 4, 11, 630.76, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-05-26', 3, 5, 4, 11, -631.79, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-06-25', 1, 10, 5, 14, 643.81, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-09-24', 2, 6, 2, 5, -550.98, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-12-29', 2, 7, 1, 3, 780.52, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-11-17', 3, 3, 3, 8, -477.41, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-05-12', 1, 4, 2, 4, -199.48, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-10-06', 1, 3, 1, 1, -527.82, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-11-07', 1, 2, 3, 8, 501.5, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-09-02', 1, 9, 3, 9, -109.69, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-12-26', 2, 4, 2, 4, -792.23, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-03-07', 2, 8, 2, 6, -514.83, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-05-06', 2, 2, 5, 13, 711.94, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-05-03', 2, 5, 5, 15, -625.87, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-07-14', 1, 2, 4, 11, -124.47, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-10-20', 1, 4, 4, 12, 386.18, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-08-10', 3, 5, 3, 8, 451.96, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-07-30', 2, 7, 4, 10, 381.85, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-10-31', 1, 10, 5, 15, -9.83, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-10-17', 2, 9, 5, 15, -423.23, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-12-28', 3, 10, 1, 3, 554.34, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-10-03', 3, 4, 5, 14, 759.49, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-02-14', 1, 6, 1, 3, -613.54, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-09-04', 2, 10, 2, 6, 64.85, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-07-24', 2, 3, 5, 15, -130.67, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-03-18', 3, 5, 1, 1, -377.28, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-10-27', 3, 4, 5, 15, -692.72, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-08-23', 1, 4, 4, 10, -467.47, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-01-01', 2, 1, 4, 11, 613.73, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-09-25', 3, 9, 2, 5, -48.33, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-01-23', 2, 8, 4, 10, -677.46, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-04-27', 2, 3, 3, 9, -140.1, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-01-27', 3, 1, 1, 1, -286.31, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-04-13', 1, 7, 5, 13, 626.48, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-06-07', 3, 4, 5, 13, 135.4, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-03-27', 2, 5, 2, 5, -352.24, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-06-28', 1, 9, 2, 6, 237.35, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-12-14', 3, 8, 1, 2, -314.24, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-05-10', 3, 9, 4, 10, 249.24, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-05-18', 1, 5, 5, 15, -144.38, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-03-09', 2, 10, 4, 10, -393.02, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-08-03', 2, 10, 5, 14, 764.58, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-03-22', 2, 3, 3, 8, -113.16, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-11-29', 3, 7, 2, 5, 203.99, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-03-11', 2, 1, 3, 8, 336.65, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-05-19', 2, 10, 5, 14, 369.03, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-12-28', 2, 2, 4, 11, -633.24, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-05-19', 2, 6, 5, 13, 500.93, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-01-19', 1, 10, 4, 12, -633.33, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-03-26', 2, 8, 4, 10, -782.98, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-02-13', 1, 8, 1, 1, -710.33, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-03-20', 1, 2, 3, 7, 468.67, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-01-19', 2, 1, 5, 15, -474.11, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-02-14', 3, 6, 3, 7, -70.82, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-05-07', 3, 5, 5, 14, 402.16, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-10-18', 1, 8, 1, 2, -302.46, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-09-01', 1, 1, 2, 6, 37.7, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-03-02', 2, 9, 3, 9, -346.33, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-05-10', 3, 2, 1, 2, -486.48, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-02-20', 2, 7, 5, 14, 24.78, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-10-05', 2, 2, 5, 15, -366.35, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-12-26', 1, 8, 4, 10, -135.42, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-10-22', 1, 3, 3, 9, -733.54, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-05-12', 2, 10, 2, 6, 548.75, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-05-26', 2, 9, 3, 9, 601.81, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-04-01', 1, 3, 2, 6, 490.99, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-10-27', 3, 7, 1, 2, -786.07, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-06-23', 1, 6, 3, 8, -277.91, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-10-05', 1, 8, 5, 13, 733.91, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-25', 3, 5, 4, 10, 119.52, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-09-26', 2, 7, 1, 3, 341.39, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-12-06', 3, 4, 4, 11, 386.91, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-01-16', 2, 7, 5, 15, 276.89, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-11-14', 1, 8, 3, 8, 663.93, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-08-02', 1, 4, 1, 3, -201.95, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-11-15', 2, 10, 3, 7, -76.82, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-08-28', 3, 10, 1, 1, -220.09, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-11-20', 1, 3, 4, 10, -660.37, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-02-21', 3, 10, 5, 14, -551.72, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-12-11', 3, 5, 4, 12, 431.82, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-01-07', 2, 8, 3, 9, 372.23, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-07-15', 2, 6, 1, 3, -167.85, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-09-07', 3, 9, 5, 15, 488.76, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-09-29', 3, 3, 2, 5, -727.88, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-09-06', 2, 4, 1, 2, 76.66, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-08-31', 3, 6, 1, 3, 451.21, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-01-30', 2, 2, 1, 1, 190.81, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-02-17', 2, 3, 4, 11, -323.88, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-01-27', 2, 3, 4, 12, 689.69, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-05-09', 2, 1, 4, 12, 87.44, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-09-15', 1, 10, 2, 4, 80.08, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-07-22', 3, 1, 3, 9, 328.77, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-08-14', 2, 8, 1, 3, 314.25, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-12-13', 2, 2, 1, 2, -591.06, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-12-04', 2, 1, 4, 11, 640.09, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-03-11', 1, 8, 4, 10, 771.87, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-04-04', 2, 1, 1, 1, -634.0, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-02-14', 1, 6, 4, 10, -429.66, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-05-08', 3, 3, 2, 4, -10.28, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-12-30', 3, 3, 2, 5, 70.8, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-04-07', 2, 3, 3, 7, 295.52, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-11-11', 1, 5, 2, 4, 656.36, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-12-09', 1, 3, 3, 8, 231.95, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-10-15', 1, 4, 2, 4, 669.17, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-07-25', 3, 1, 5, 15, 659.91, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-05-23', 2, 6, 3, 9, -782.38, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-04-04', 2, 10, 4, 10, -300.22, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-11-02', 2, 10, 2, 4, -761.47, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-11-12', 2, 3, 1, 1, 318.33, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-11-04', 2, 4, 1, 2, 347.25, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-01-14', 3, 8, 2, 5, 283.01, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-11-17', 1, 10, 1, 2, -113.69, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-26', 3, 9, 4, 10, -370.18, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-06-28', 3, 8, 4, 12, -251.57, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-05-16', 2, 6, 3, 8, -317.4, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-10-23', 1, 8, 3, 8, 120.57, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-02-25', 3, 9, 2, 4, -749.59, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-04-29', 2, 9, 4, 11, 360.74, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-01-30', 3, 9, 5, 14, -781.9, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-02-22', 3, 10, 1, 3, -396.65, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-06-25', 1, 7, 5, 14, 791.03, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-01-04', 3, 8, 1, 1, -365.79, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-06-27', 1, 3, 3, 8, -379.47, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-06-02', 1, 1, 3, 8, -100.52, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-04-06', 3, 9, 1, 1, -183.59, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-01-23', 2, 3, 2, 4, -184.88, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-01-03', 1, 2, 5, 13, 571.48, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-07-10', 3, 9, 2, 6, -696.68, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-12-01', 1, 2, 4, 10, 91.0, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-01-11', 3, 9, 3, 8, -7.72, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-11-03', 1, 9, 5, 14, 629.78, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-04-09', 3, 4, 1, 1, -693.98, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-02-08', 3, 3, 2, 5, -708.42, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-07-26', 1, 7, 1, 2, -205.53, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-07-01', 1, 7, 3, 8, -509.15, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-02-08', 2, 5, 3, 7, 623.3, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-11-29', 2, 6, 5, 15, -69.35, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-09-14', 1, 3, 1, 1, -63.21, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-11-14', 3, 2, 2, 6, -741.83, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-05-27', 2, 5, 2, 4, 731.02, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-03-14', 3, 4, 4, 12, -693.64, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-03-26', 1, 7, 2, 4, 384.69, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-09-11', 1, 6, 2, 5, -114.53, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-04-17', 1, 8, 5, 14, 721.45, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-10-03', 3, 7, 3, 8, -343.0, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-10-11', 1, 4, 5, 14, 394.3, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-12-04', 2, 3, 1, 2, 456.3, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-08-05', 1, 9, 2, 4, -37.95, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-07-19', 3, 5, 3, 8, 793.34, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-09-26', 1, 9, 2, 4, 522.03, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-10-09', 3, 1, 5, 15, 27.33, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-09-11', 2, 10, 3, 7, -231.93, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-10-06', 1, 9, 1, 3, 396.59, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-08-06', 1, 4, 1, 1, -697.08, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-11-11', 3, 6, 1, 1, 212.44, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-04-20', 2, 10, 4, 12, 175.16, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-05-24', 1, 5, 1, 3, 189.94, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-02', 2, 3, 3, 7, -220.44, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-10-13', 3, 3, 2, 5, 339.06, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-01-12', 3, 10, 4, 11, 77.41, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-07-09', 1, 1, 4, 10, -357.15, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-01-15', 1, 2, 5, 14, 513.57, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-02-27', 2, 5, 3, 8, -635.09, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-04-05', 3, 8, 4, 11, 791.71, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-05-26', 3, 6, 4, 11, -700.73, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-01-23', 2, 2, 3, 8, -334.15, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-12-10', 1, 6, 2, 5, 714.78, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-11-25', 1, 4, 2, 4, 498.84, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-03-20', 2, 2, 5, 13, -437.85, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-01-19', 1, 10, 2, 4, -236.53, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-10-26', 3, 2, 4, 11, 543.16, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-12-25', 1, 9, 2, 5, 353.51, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-06-12', 1, 2, 2, 4, -42.89, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-01-03', 2, 2, 3, 8, 549.49, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-12-22', 2, 1, 3, 8, 432.53, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-04-22', 2, 5, 1, 2, 20.46, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-04-15', 1, 10, 4, 10, 513.76, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-06-14', 1, 1, 4, 10, -427.63, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-02-27', 3, 5, 3, 8, 691.13, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-10-12', 1, 2, 3, 9, 600.19, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-10-08', 2, 6, 2, 5, 431.61, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-11-16', 2, 10, 4, 10, -479.11, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-12-19', 1, 8, 4, 11, -653.09, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-01-21', 1, 10, 2, 6, 631.7, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-06', 1, 3, 5, 15, 703.32, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-12-09', 3, 6, 1, 2, -40.58, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-01-27', 2, 4, 4, 11, 316.49, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-10-05', 1, 8, 5, 14, -412.57, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-12-19', 1, 4, 3, 7, -112.69, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-05-06', 1, 7, 3, 7, 492.04, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-10-24', 2, 1, 4, 12, 296.65, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-01-12', 2, 1, 2, 4, 159.85, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-08-15', 2, 8, 2, 6, -162.75, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-02-11', 2, 10, 5, 13, 373.48, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-09-23', 3, 10, 3, 7, 55.41, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-09-17', 2, 8, 1, 3, 310.5, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-07-12', 1, 8, 1, 2, 679.4, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-05-08', 2, 6, 1, 3, -487.6, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-05-06', 3, 2, 1, 1, -257.21, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-07-02', 2, 3, 3, 8, -430.34, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-11-10', 2, 9, 3, 7, 720.59, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-03-14', 2, 8, 3, 8, 68.47, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-02-19', 2, 8, 4, 11, 472.59, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-08-31', 2, 4, 3, 8, 563.6, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-06-04', 3, 6, 2, 6, 738.26, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-05-28', 2, 7, 1, 3, -180.38, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-11-27', 2, 6, 1, 1, 171.31, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-06-01', 3, 8, 3, 7, 553.83, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-05-31', 1, 4, 3, 9, -360.22, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-04-26', 1, 6, 3, 7, 158.27, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-02-04', 3, 6, 4, 12, 460.86, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-09-23', 1, 7, 1, 2, 616.39, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-11-01', 1, 9, 5, 14, -447.19, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-10-26', 1, 6, 3, 9, -420.73, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-11-12', 3, 5, 1, 2, -109.08, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-01-31', 2, 10, 4, 11, -743.37, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-10-30', 2, 1, 2, 6, 208.09, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-02-14', 3, 6, 2, 4, -796.27, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-11-02', 3, 5, 4, 12, 180.83, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-12-11', 3, 6, 2, 6, 244.51, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-12-15', 3, 2, 3, 7, 321.23, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-01-29', 1, 10, 5, 13, 118.98, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-09-29', 3, 9, 4, 12, 16.49, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-04-06', 3, 10, 4, 11, -551.33, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-02-04', 1, 1, 1, 1, 395.49, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-12-03', 1, 1, 5, 14, -261.06, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-09-02', 3, 2, 4, 12, 702.86, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-04-02', 2, 4, 3, 7, 588.66, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-08-16', 1, 7, 2, 6, 424.76, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-08-17', 3, 7, 5, 14, 242.82, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-12-30', 3, 9, 3, 8, -5.61, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-04-27', 3, 8, 3, 8, 518.64, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-07-10', 2, 1, 4, 12, 495.37, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-07-15', 2, 4, 5, 15, -652.68, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-10-20', 3, 5, 5, 15, 350.91, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-12-27', 3, 7, 5, 15, -241.74, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-05-05', 3, 6, 1, 3, -130.9, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-09-04', 3, 2, 5, 15, -391.09, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-02-12', 2, 10, 2, 5, 707.04, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-04-10', 3, 6, 4, 11, 198.85, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-05-25', 3, 9, 3, 7, -170.26, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-12-02', 2, 10, 3, 7, -655.58, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-10-22', 2, 8, 3, 7, 78.73, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-11-18', 3, 6, 4, 12, -683.66, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-08-07', 1, 1, 3, 9, -606.4, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-11-20', 1, 1, 5, 15, -352.7, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-10-26', 1, 1, 1, 1, 466.13, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-09-04', 2, 5, 4, 12, -129.65, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-02-20', 1, 1, 4, 12, -454.68, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-05-21', 1, 2, 1, 3, 28.89, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-05-06', 3, 2, 2, 5, 268.63, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-04-26', 1, 5, 5, 14, -449.09, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-03-04', 1, 4, 5, 15, -14.23, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-10-31', 3, 6, 1, 1, -249.31, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-05-23', 2, 1, 3, 8, 430.24, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-03-26', 3, 7, 3, 7, 536.64, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-06-16', 3, 3, 5, 15, 45.22, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-08-10', 1, 5, 5, 13, -131.53, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-05-28', 3, 8, 1, 3, -591.45, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-12-03', 1, 4, 2, 4, 638.45, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-05-24', 2, 3, 4, 10, -262.92, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-08-30', 3, 1, 3, 7, 282.36, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-01-30', 3, 4, 4, 12, 688.16, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-03-09', 1, 6, 3, 8, -486.63, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-04-05', 1, 1, 2, 5, 768.59, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-06-19', 3, 8, 5, 15, 394.62, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-01-10', 1, 4, 4, 12, -739.23, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-10-17', 3, 3, 3, 9, -671.56, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-10-15', 3, 10, 1, 3, 222.87, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-07-23', 1, 3, 1, 1, 209.93, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-09-14', 1, 5, 1, 1, -122.48, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-09-10', 1, 6, 5, 14, -191.65, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-02-09', 3, 7, 5, 13, 792.06, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-12-10', 1, 1, 2, 4, -255.32, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-03-13', 3, 6, 5, 13, -337.88, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-10-09', 3, 8, 1, 2, 128.82, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-08-03', 2, 9, 3, 8, -543.13, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-11-15', 1, 8, 5, 14, -700.42, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-01-06', 1, 6, 4, 12, -154.43, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-04-18', 3, 9, 2, 4, 714.78, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-10-12', 2, 2, 1, 3, -214.03, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-05-14', 1, 9, 2, 4, -753.1, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-04-16', 3, 2, 3, 7, 739.85, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-02-13', 3, 3, 1, 1, -215.13, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-09-14', 2, 6, 2, 5, 400.27, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-08-23', 3, 4, 3, 7, 617.97, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-09-24', 2, 7, 5, 13, 799.93, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-04-17', 2, 1, 5, 15, -368.34, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-07-24', 2, 10, 1, 3, 579.81, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-10-13', 3, 8, 4, 11, -687.85, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-03-21', 2, 3, 2, 5, 518.65, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-06-08', 2, 8, 3, 9, -190.65, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-06-30', 2, 4, 2, 5, 401.57, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-09-26', 1, 6, 1, 3, -86.41, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-27', 3, 5, 4, 11, 230.22, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-09-11', 2, 9, 4, 12, 479.04, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-11-06', 2, 4, 1, 1, 544.83, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-12-20', 3, 1, 1, 1, 107.04, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-09-08', 3, 10, 3, 7, -505.0, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-01-06', 2, 4, 4, 12, 193.6, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-11-06', 2, 9, 4, 10, -438.0, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-03-18', 2, 8, 3, 9, -312.09, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-12-18', 2, 7, 2, 6, 97.2, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-11-25', 2, 6, 3, 9, 657.9, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-05-25', 3, 10, 2, 5, 660.69, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-11-05', 1, 1, 2, 4, -529.22, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-12-19', 3, 3, 5, 15, -717.09, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-10-09', 1, 8, 2, 5, 602.88, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-07-09', 3, 1, 4, 12, -415.81, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-02-27', 2, 10, 4, 11, 751.55, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-03-04', 2, 7, 4, 12, 649.7, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-05-13', 2, 2, 5, 15, -725.74, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-09-01', 1, 3, 1, 2, 144.5, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-08-11', 2, 7, 3, 8, 305.48, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-12-27', 2, 4, 4, 10, -161.03, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-08-21', 2, 4, 1, 1, -83.89, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-01-25', 1, 6, 5, 15, 338.74, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-01-27', 3, 5, 2, 6, 651.58, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-12-28', 1, 2, 1, 2, -362.22, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-01-09', 1, 2, 1, 2, 708.04, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-06-20', 3, 8, 1, 2, 704.18, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-02-25', 3, 8, 5, 15, 421.16, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-06-09', 1, 8, 2, 4, -421.89, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-09-03', 3, 2, 2, 4, -405.54, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-09-20', 3, 9, 2, 6, 484.36, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-04-10', 1, 7, 4, 11, 603.9, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-04-15', 2, 6, 3, 8, 670.18, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-07-06', 2, 8, 5, 15, 470.58, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-05-20', 2, 8, 5, 13, 637.5, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-05-18', 2, 2, 2, 5, -94.9, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-09-09', 2, 7, 3, 9, 554.03, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-10-06', 2, 9, 1, 1, 56.18, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-08-20', 2, 4, 3, 9, -619.43, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-04-13', 1, 8, 3, 9, 167.33, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-09-03', 2, 8, 2, 4, -18.96, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-02-07', 1, 6, 4, 10, -170.13, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-12-27', 3, 10, 5, 15, -248.45, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-02-26', 1, 8, 5, 14, -328.48, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-02-16', 2, 7, 5, 15, -402.04, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-04-27', 3, 6, 3, 7, -631.6, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-05-02', 1, 1, 4, 11, 73.66, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-09-11', 2, 4, 5, 13, -708.18, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-12-11', 1, 5, 3, 8, 135.07, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-12-17', 3, 3, 3, 8, -264.8, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-10-05', 2, 3, 4, 11, -791.01, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-09-30', 2, 9, 5, 15, -636.9, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-21', 2, 1, 5, 13, 347.27, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-02-05', 3, 10, 1, 1, -314.26, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-01-21', 3, 9, 3, 9, 391.18, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-01-20', 3, 4, 4, 10, 354.01, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-03-23', 2, 10, 1, 1, 563.82, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-03-21', 1, 2, 1, 3, 468.56, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-01-04', 2, 5, 5, 15, -705.9, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-11-09', 3, 8, 2, 5, 710.57, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-08-10', 1, 9, 3, 7, 740.83, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-11-24', 2, 2, 5, 15, 628.04, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-08-28', 3, 4, 5, 14, -331.79, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-05-12', 2, 7, 5, 15, 565.48, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-09-05', 1, 5, 2, 5, 737.57, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-07-07', 2, 8, 5, 13, 153.81, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-05-27', 3, 5, 3, 7, -694.77, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-09-07', 2, 4, 1, 1, -683.59, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-06-21', 2, 6, 1, 1, 99.33, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-07-10', 3, 3, 5, 14, 508.2, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-10-11', 3, 7, 3, 7, 266.06, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-02-03', 2, 7, 1, 3, -283.82, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-11-30', 3, 7, 4, 12, -433.35, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-05-21', 1, 8, 2, 5, -264.06, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-12-15', 1, 1, 2, 6, -673.66, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-03-19', 1, 2, 2, 5, -584.68, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-05-03', 1, 3, 2, 4, 794.6, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-08-30', 3, 6, 2, 5, 112.16, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-11-26', 1, 3, 5, 14, -572.73, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-02-13', 2, 3, 2, 4, -128.1, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-11-21', 2, 2, 2, 6, -190.14, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-10-16', 3, 8, 1, 3, -778.58, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-01-21', 3, 2, 5, 15, -83.66, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-06-01', 1, 2, 4, 12, 113.14, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-05-15', 2, 1, 5, 14, 491.94, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-02-07', 3, 8, 2, 5, -529.14, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-10-07', 1, 10, 4, 12, 176.39, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-09-03', 2, 10, 5, 15, -440.35, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-12-09', 3, 2, 3, 7, -244.26, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-05-06', 2, 10, 2, 5, 594.38, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-04-18', 1, 4, 4, 12, -42.02, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-05-18', 3, 10, 4, 11, 106.25, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-06-18', 2, 7, 2, 4, -490.73, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-15', 1, 3, 4, 11, -113.06, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-04-27', 1, 3, 2, 5, -604.95, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-12-22', 2, 6, 5, 14, 501.09, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-01-15', 3, 10, 1, 1, -173.45, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-07-23', 1, 9, 1, 2, 613.33, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-05-07', 3, 2, 3, 8, -146.47, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-10-19', 1, 7, 2, 4, -613.56, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-05-02', 1, 7, 1, 2, 419.17, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-07-17', 1, 6, 3, 7, -296.05, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-12-18', 3, 10, 1, 3, 332.65, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-08-07', 1, 4, 2, 5, -179.62, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-02-14', 3, 3, 4, 11, 417.23, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-02-05', 3, 4, 3, 7, -683.08, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-02-12', 3, 6, 5, 14, -575.64, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-10-29', 3, 3, 4, 10, 653.69, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-04-09', 1, 5, 2, 5, 191.3, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-12-17', 2, 4, 2, 4, 495.26, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-07-23', 1, 10, 1, 1, 97.16, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-06-05', 3, 7, 5, 15, -489.88, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-04-14', 3, 5, 3, 7, -321.78, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-07-25', 1, 2, 4, 12, -711.32, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-08-03', 3, 7, 4, 12, -378.77, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-06-20', 2, 10, 3, 9, -407.8, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-10-13', 1, 4, 2, 5, -719.25, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-05-08', 3, 6, 3, 8, -685.66, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-12-20', 2, 8, 5, 13, 331.96, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-01-19', 3, 4, 5, 13, -243.11, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-04-08', 3, 9, 4, 12, -384.52, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-02-26', 2, 8, 5, 14, 395.51, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-11-04', 1, 5, 5, 14, -70.76, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-05-29', 1, 1, 1, 2, -77.22, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-05-26', 1, 6, 1, 2, -160.28, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-06-10', 2, 1, 1, 2, 462.53, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-01-01', 2, 5, 5, 14, 643.08, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-02-02', 1, 7, 1, 2, -110.68, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-06-29', 1, 5, 2, 4, -462.01, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-08-30', 3, 4, 5, 13, 224.64, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-09-05', 3, 6, 5, 13, -193.35, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-07-05', 2, 9, 5, 15, -90.83, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-09-28', 3, 5, 4, 12, -795.7, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-04-05', 3, 6, 4, 11, -578.69, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-05-16', 1, 6, 3, 9, -385.97, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-12-17', 3, 7, 1, 2, 380.01, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-04-27', 3, 8, 5, 14, -141.63, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-10-28', 3, 6, 1, 1, -408.54, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-04-18', 2, 6, 4, 10, -269.49, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-02-04', 1, 6, 3, 9, -592.71, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-09-06', 3, 5, 1, 2, 331.12, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-01-28', 3, 2, 2, 5, 609.99, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-02-26', 3, 6, 3, 9, 309.94, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-04-13', 1, 7, 4, 11, 616.79, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-03-23', 1, 7, 4, 12, -798.29, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-09-04', 1, 5, 1, 3, 589.94, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-11-24', 3, 3, 1, 1, -375.7, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-01-03', 3, 2, 3, 7, 637.92, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-08-17', 3, 6, 5, 14, -72.67, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-02-25', 2, 5, 5, 14, -447.34, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-09-09', 3, 3, 2, 4, 698.64, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-03-14', 2, 5, 3, 9, 21.45, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-12-30', 2, 8, 4, 11, -330.12, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-09-09', 2, 10, 2, 6, -8.69, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-06-14', 2, 10, 2, 4, -262.09, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-07-07', 2, 5, 1, 1, 740.66, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-12-27', 2, 10, 5, 14, 742.7, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-07-24', 2, 1, 3, 7, -452.75, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-06-09', 2, 2, 3, 9, -623.79, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-02-08', 2, 5, 4, 11, 195.57, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-10-21', 1, 10, 4, 10, -104.18, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-08-06', 2, 8, 5, 14, -556.08, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-05-01', 3, 4, 2, 4, 792.39, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-02-22', 2, 2, 1, 3, 706.8, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-08-09', 3, 10, 4, 12, 740.3, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-11-23', 1, 10, 4, 11, -682.71, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-04-05', 3, 1, 3, 9, 148.29, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-07-31', 3, 2, 4, 11, 226.77, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-01-14', 3, 2, 5, 13, -120.13, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-02-12', 2, 9, 1, 1, 306.67, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-10-09', 2, 7, 1, 1, 437.41, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-09-12', 2, 6, 2, 4, -13.18, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-10-22', 1, 2, 4, 10, -606.94, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-08-22', 2, 3, 5, 14, 7.8, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-02-07', 3, 4, 1, 2, 467.58, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-06-05', 3, 6, 4, 11, 38.43, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-07-25', 2, 10, 5, 13, -39.41, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-05-25', 1, 8, 3, 7, 371.03, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-11-24', 3, 2, 1, 1, -272.98, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-05-17', 1, 3, 1, 2, 290.16, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-01-22', 1, 1, 5, 13, -782.68, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-02-24', 3, 10, 1, 2, 16.99, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-03-20', 3, 1, 4, 11, 133.88, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-01-21', 3, 3, 1, 2, 698.09, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-09-13', 2, 10, 1, 1, 567.02, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-10-15', 1, 2, 1, 2, -539.49, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-07-02', 3, 5, 3, 7, -644.39, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-06-24', 2, 9, 2, 6, -104.18, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-07-23', 3, 5, 2, 6, 88.33, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-01-16', 1, 4, 3, 7, 731.02, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-02-24', 1, 4, 5, 15, 571.71, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-02-18', 2, 6, 2, 4, -666.37, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-11-22', 3, 5, 5, 14, 390.79, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-04-25', 3, 4, 4, 12, -457.02, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-04-05', 2, 6, 4, 11, -92.84, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-04-02', 2, 4, 4, 11, -435.54, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-07-05', 1, 4, 4, 11, -672.73, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-01-31', 3, 2, 3, 8, -289.57, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-07-28', 3, 1, 2, 5, -37.24, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-02-03', 2, 8, 4, 10, 385.48, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-05-05', 1, 6, 1, 3, -717.61, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-02-23', 3, 10, 5, 14, -42.78, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-05-11', 2, 2, 4, 10, -422.02, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-03-09', 1, 4, 4, 11, -13.51, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-06-20', 2, 7, 1, 1, 195.09, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-11-28', 3, 1, 5, 14, -348.63, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-01-27', 3, 4, 1, 1, -496.9, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-02-17', 3, 9, 3, 7, 40.08, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-06-07', 3, 9, 4, 11, 375.85, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-04-27', 2, 3, 5, 14, -558.79, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-12-18', 3, 4, 1, 2, -211.66, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-01-09', 2, 6, 1, 1, -524.27, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-02-01', 1, 1, 3, 9, -107.78, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-08-26', 2, 10, 1, 2, 773.25, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-10-22', 2, 2, 2, 4, 128.95, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-09-29', 2, 7, 5, 15, 290.09, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-06-01', 3, 8, 5, 15, 786.85, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-09-22', 1, 7, 1, 2, -701.94, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-05-27', 3, 8, 2, 6, 693.35, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-12-15', 1, 10, 3, 7, 659.55, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-06-26', 1, 6, 4, 12, -271.16, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-04-19', 3, 2, 4, 11, -420.37, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-03-07', 2, 4, 2, 5, -500.85, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-06-07', 2, 6, 5, 14, 243.56, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-07-21', 1, 7, 2, 4, 371.02, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-05-23', 2, 5, 1, 1, -30.82, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-05-10', 3, 5, 4, 10, -292.88, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-09-04', 1, 5, 4, 12, -24.88, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-11-15', 3, 2, 5, 15, -581.33, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-08-01', 3, 8, 1, 2, -315.96, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-08-12', 3, 3, 3, 9, -448.2, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-03-18', 2, 7, 1, 1, 214.22, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-09-11', 1, 7, 3, 8, 412.91, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-01-16', 2, 6, 2, 4, 623.62, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-02-14', 1, 8, 2, 5, -75.47, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-12-04', 2, 8, 1, 1, 260.34, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-11-17', 2, 9, 1, 3, -481.05, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-03-30', 1, 5, 4, 12, -738.5, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-11-21', 2, 4, 1, 3, 702.48, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-04-27', 1, 5, 4, 11, 148.19, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-05-15', 1, 6, 1, 3, 719.13, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-13', 2, 9, 2, 4, -250.75, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-06-02', 1, 2, 1, 2, -663.68, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-04-09', 2, 2, 4, 11, 39.94, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-04-02', 3, 9, 5, 14, 197.81, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-12-23', 1, 5, 4, 11, -593.2, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-05-20', 1, 2, 2, 5, -413.69, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-10-25', 3, 3, 2, 4, -709.56, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-01-23', 1, 9, 5, 14, -457.28, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-09-12', 2, 7, 1, 3, 338.04, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-05-04', 3, 10, 2, 6, 462.02, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-05-28', 3, 4, 3, 8, 193.06, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-11-29', 3, 2, 3, 8, -769.32, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-07-20', 1, 10, 4, 11, 9.32, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-07-05', 3, 9, 3, 7, -331.85, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-04-12', 1, 3, 3, 9, 290.16, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-04-06', 3, 6, 3, 7, -149.89, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-08-16', 2, 4, 4, 12, 382.69, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-06-30', 3, 5, 5, 13, -566.55, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-11-23', 3, 9, 1, 3, 119.45, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-01-29', 3, 4, 4, 11, 159.02, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-03-29', 2, 10, 4, 12, 230.04, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-06-06', 2, 3, 3, 7, -470.64, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-07-26', 3, 10, 2, 5, -677.24, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-01-16', 1, 2, 2, 5, 7.58, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-11-13', 1, 4, 5, 14, -310.63, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-03-12', 1, 6, 5, 15, 587.06, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-02-26', 3, 6, 2, 6, -414.48, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-11-10', 3, 8, 4, 10, -405.4, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-01-25', 3, 3, 5, 15, -592.36, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-12-16', 2, 10, 1, 1, 748.4, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-02-08', 3, 2, 5, 15, -349.27, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-02-27', 3, 4, 5, 15, -22.72, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-12-15', 1, 4, 5, 13, 504.02, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-11-30', 1, 3, 5, 15, 163.17, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-02-03', 3, 10, 2, 4, 14.89, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-11-26', 1, 7, 5, 14, 608.82, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-03-12', 3, 1, 2, 4, 705.3, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-05-04', 3, 1, 5, 13, 540.69, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-01-09', 1, 3, 4, 12, -72.02, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-02-08', 1, 6, 4, 12, 398.36, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-06-27', 1, 1, 1, 2, -693.79, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-03-13', 3, 7, 5, 15, -618.14, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-07-12', 1, 9, 4, 11, 198.46, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-07-06', 2, 3, 4, 10, -173.3, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-06-26', 1, 2, 3, 7, -204.28, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-01-29', 1, 10, 2, 4, 675.44, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-11-29', 2, 1, 2, 4, -326.2, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-02-12', 2, 6, 4, 12, -255.62, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-02-19', 2, 4, 1, 2, 705.99, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-12-25', 2, 6, 5, 15, 369.69, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-02-18', 3, 5, 3, 8, -428.84, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-10-07', 1, 4, 3, 7, 73.61, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-01-27', 1, 4, 3, 8, 562.37, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-03-24', 2, 5, 3, 7, -196.57, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-05-04', 1, 6, 1, 3, 608.42, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-08-22', 1, 3, 1, 2, 462.46, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-03-09', 1, 3, 5, 13, 350.43, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-05-18', 1, 7, 1, 2, -615.24, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-12-22', 3, 10, 1, 2, 575.87, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-07-16', 3, 9, 1, 3, 634.56, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-12-20', 3, 2, 2, 4, 788.33, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-02-05', 1, 6, 1, 2, 229.07, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-08-09', 3, 4, 3, 7, -63.15, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-09-06', 3, 9, 3, 8, 752.93, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-07-17', 2, 10, 2, 4, 22.91, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-09-15', 1, 7, 5, 15, 38.54, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-02-12', 3, 1, 4, 11, -617.01, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-10-29', 3, 9, 1, 3, -772.62, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-07-05', 3, 1, 2, 5, -600.46, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-06-13', 2, 8, 3, 7, -670.63, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-04-11', 1, 5, 1, 2, -260.97, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-03-24', 1, 10, 2, 5, 505.97, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-11-09', 3, 4, 3, 9, -524.19, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-06-08', 2, 9, 4, 11, -461.86, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-08-13', 2, 7, 4, 10, 476.65, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-05-15', 2, 9, 2, 4, -203.79, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-02-25', 1, 7, 5, 15, 51.3, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-07-08', 2, 4, 2, 6, -23.75, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-01-15', 2, 8, 5, 15, -295.61, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-04-01', 3, 1, 5, 13, -278.66, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-02-07', 3, 5, 1, 2, 103.95, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-01-24', 1, 5, 4, 12, 478.98, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-10-16', 2, 1, 2, 4, 304.4, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-11-27', 3, 2, 2, 5, -52.05, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-02-12', 1, 8, 5, 14, 240.81, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-10-02', 2, 3, 2, 4, -423.8, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-01-24', 2, 4, 1, 2, 681.87, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-09-15', 2, 10, 1, 2, -174.22, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-11-20', 2, 5, 5, 15, -30.91, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-08-16', 1, 3, 5, 13, 55.94, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-08-13', 2, 1, 3, 9, 171.78, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-10-17', 3, 7, 2, 4, -619.89, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-04-17', 3, 2, 2, 5, 611.15, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-06-15', 2, 8, 2, 6, -411.7, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-01-05', 1, 9, 2, 5, -350.23, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-07-25', 3, 3, 1, 1, 422.43, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-10-03', 2, 1, 1, 1, -10.69, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-04-15', 2, 5, 5, 13, -762.7, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-02-14', 1, 5, 5, 15, -434.49, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-01-30', 3, 10, 4, 10, 272.36, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-07-14', 3, 2, 1, 3, 43.55, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-02-03', 1, 4, 5, 15, -528.3, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-12-16', 3, 9, 3, 7, 652.41, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-07-26', 1, 4, 5, 13, 240.27, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-11-16', 2, 7, 2, 4, 444.8, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-07-20', 2, 6, 2, 4, -498.67, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-03-23', 3, 9, 4, 10, -83.65, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-07-09', 3, 3, 1, 3, -241.11, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-12-09', 3, 9, 5, 15, 319.85, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-09-11', 3, 10, 5, 13, -148.76, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-04-11', 2, 9, 4, 10, 447.58, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-09-04', 2, 4, 4, 11, -607.18, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-04-23', 2, 4, 5, 14, -261.06, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-04-18', 2, 9, 5, 13, 396.5, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-04-17', 2, 10, 3, 9, -679.09, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-03-26', 1, 7, 2, 6, 182.75, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-03-18', 3, 8, 1, 1, -295.51, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-04-24', 1, 8, 5, 13, 367.86, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-01-31', 1, 2, 1, 2, 579.04, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-06-02', 1, 5, 1, 1, -277.37, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-01-02', 3, 6, 5, 15, 443.2, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-03-06', 1, 9, 2, 5, 123.26, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-09-28', 1, 9, 2, 5, 47.94, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-06-15', 2, 6, 3, 7, 460.6, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-04-15', 3, 7, 4, 10, 215.18, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-03-26', 2, 8, 2, 5, -293.48, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-09-19', 3, 4, 3, 8, -775.49, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-09-15', 2, 5, 5, 15, 574.23, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-12-09', 1, 3, 1, 1, -481.61, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-06-13', 3, 10, 3, 9, -615.44, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-08-01', 3, 7, 2, 5, 628.19, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-11-05', 2, 8, 5, 14, 658.44, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-10-20', 2, 6, 2, 5, -615.62, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-06-03', 3, 8, 3, 8, -19.6, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-01-15', 2, 1, 2, 5, 601.22, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-07-07', 2, 5, 2, 6, 490.91, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-04-22', 1, 5, 1, 3, -126.84, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-09-27', 3, 8, 4, 12, -245.24, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-09-15', 2, 4, 5, 14, 339.04, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-01-05', 3, 2, 4, 10, -545.98, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-07-09', 3, 3, 5, 15, 132.9, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-08-29', 3, 10, 5, 13, 282.34, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-07-26', 1, 2, 2, 6, -28.83, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-09-20', 3, 2, 1, 1, 84.0, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-04-02', 3, 9, 1, 1, 626.29, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-04-23', 2, 1, 1, 2, 378.74, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-10-27', 1, 10, 3, 8, 520.96, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-04-21', 1, 5, 2, 4, -435.52, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-05-14', 1, 8, 1, 3, -648.33, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-09-29', 2, 10, 5, 13, -16.59, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-02-03', 1, 5, 5, 13, -579.91, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-09-12', 3, 4, 2, 6, 328.32, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-09-29', 1, 4, 3, 8, 425.59, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-07-15', 3, 9, 4, 12, -410.88, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-03-05', 1, 10, 5, 13, 257.99, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-08-28', 1, 5, 2, 4, 350.3, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-11-20', 1, 5, 4, 11, 520.12, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-09-30', 1, 2, 1, 2, -636.29, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-09-03', 3, 1, 1, 1, 426.35, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-09-20', 1, 5, 3, 8, -439.61, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-03-18', 2, 8, 2, 6, -238.9, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-09-04', 1, 2, 2, 4, -28.49, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-06-29', 1, 4, 5, 13, 452.98, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-02-09', 1, 7, 2, 4, 716.55, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-03-14', 1, 9, 2, 5, 156.39, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-07-19', 2, 3, 2, 5, -183.76, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-02-16', 3, 1, 2, 5, 453.49, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-09-21', 1, 9, 1, 1, 558.3, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-09-10', 3, 1, 1, 1, 558.54, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-07-28', 3, 9, 2, 5, 61.85, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-03-17', 2, 8, 1, 1, 55.48, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-02-20', 3, 2, 5, 15, 725.16, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-02-24', 2, 9, 5, 13, -774.98, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-02-10', 3, 1, 2, 4, -550.69, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-09-01', 2, 4, 5, 14, -624.74, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-07-29', 3, 8, 5, 14, 694.1, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-04-04', 1, 2, 5, 14, 788.37, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-06-24', 1, 7, 4, 12, -650.56, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-07-29', 2, 9, 2, 5, -641.45, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-01-03', 1, 6, 5, 14, 624.05, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-09-08', 3, 6, 1, 2, -313.67, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-12-30', 2, 7, 4, 11, 393.15, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-10-01', 3, 5, 5, 15, 762.21, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-07-12', 3, 1, 4, 10, 666.69, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-03-01', 2, 1, 1, 1, -532.81, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-03-29', 1, 6, 3, 9, -476.47, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-05-24', 3, 8, 1, 3, 666.58, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-08-28', 1, 4, 4, 10, 313.36, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-03-31', 3, 7, 4, 12, 317.31, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-01-25', 1, 1, 5, 14, 524.39, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-09-04', 3, 2, 2, 5, -37.64, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-12-29', 2, 10, 2, 6, 479.33, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-09-01', 1, 6, 1, 3, 438.82, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-06-02', 1, 7, 4, 10, -473.86, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-12-03', 2, 6, 5, 14, -619.76, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-05-09', 2, 9, 4, 10, 457.88, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-10-29', 1, 7, 2, 4, -108.58, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-10-24', 2, 8, 3, 8, -21.24, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-01-14', 1, 1, 2, 4, -380.81, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-05-24', 3, 6, 2, 5, 306.8, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-10-20', 2, 7, 1, 2, 650.12, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-09-24', 1, 8, 4, 11, -475.43, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-02-05', 2, 10, 2, 5, -435.35, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-07-12', 2, 9, 3, 9, -516.41, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-07-08', 2, 7, 2, 4, 611.34, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-11-19', 1, 6, 4, 10, 579.47, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-03-20', 2, 3, 2, 5, 136.44, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-06-27', 3, 7, 4, 12, -647.08, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-06-25', 1, 8, 5, 14, 239.76, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-06-13', 1, 7, 4, 10, -479.32, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-04-09', 3, 2, 2, 6, -667.79, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-06-27', 2, 9, 2, 4, 185.5, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-01-24', 2, 4, 4, 11, -689.92, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-03-12', 2, 3, 4, 12, -179.21, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-12-22', 3, 10, 5, 15, 102.96, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-07-01', 2, 8, 3, 8, 767.73, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-07-22', 3, 5, 2, 6, -316.98, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-05-14', 3, 3, 2, 6, -527.63, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-09-27', 1, 2, 4, 11, 494.96, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-10-07', 3, 8, 1, 2, -742.36, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-05-03', 1, 3, 2, 5, -54.6, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-12-05', 1, 6, 2, 5, -405.65, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-09-21', 3, 1, 5, 15, 280.82, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-11-30', 1, 2, 4, 12, 317.25, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-03-11', 3, 6, 4, 11, 320.68, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-08-06', 1, 5, 1, 2, -34.52, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-03-06', 3, 4, 5, 15, 53.2, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-05-25', 2, 3, 2, 5, 564.21, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-04-14', 3, 4, 1, 1, -750.88, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-08-19', 1, 2, 3, 7, -285.63, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-05-06', 1, 10, 3, 8, -375.07, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-11-25', 3, 2, 5, 15, -129.78, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-06-02', 3, 7, 2, 4, 360.87, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-02-02', 1, 10, 3, 8, -558.8, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-12-06', 3, 1, 1, 1, 26.12, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-12-25', 2, 5, 1, 3, -485.34, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-01-11', 1, 3, 4, 12, 498.8, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-06-26', 1, 10, 2, 6, 633.44, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-06-01', 1, 2, 4, 11, -717.8, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-09-17', 1, 8, 5, 14, -356.39, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-08-15', 3, 8, 1, 3, -735.55, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-10-22', 1, 9, 4, 11, -401.76, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-09-07', 1, 8, 4, 11, 319.42, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-08-29', 3, 4, 1, 3, -176.56, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-04-01', 3, 5, 2, 4, -750.69, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-05-13', 1, 9, 3, 8, 565.98, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-07-22', 3, 6, 2, 5, 385.0, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-08-07', 1, 2, 5, 14, -53.9, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-08-06', 2, 2, 1, 2, 355.83, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-02-03', 1, 8, 3, 7, -622.04, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-12-26', 3, 6, 5, 13, 291.27, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-04-23', 2, 4, 5, 13, 406.22, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-02-17', 2, 3, 1, 2, 540.98, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-09-06', 2, 3, 2, 4, 771.76, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-06-12', 1, 2, 3, 9, -719.63, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-05-15', 3, 2, 1, 3, 425.06, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-09-01', 1, 3, 1, 1, 238.35, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-12-22', 1, 10, 4, 12, 584.31, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-07-27', 2, 7, 2, 6, -148.46, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-04-09', 2, 5, 2, 6, 419.52, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-07-12', 3, 5, 4, 12, -583.57, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-03-14', 2, 7, 5, 13, -11.4, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-07-29', 3, 6, 1, 2, 176.84, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-11-21', 1, 2, 5, 14, 121.36, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-11-07', 3, 4, 2, 4, 666.65, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-03-10', 2, 5, 5, 13, -705.57, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-04-06', 2, 7, 4, 10, -685.13, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-03-22', 1, 7, 4, 11, -58.51, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-06-04', 2, 5, 4, 11, 278.8, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-09-04', 1, 10, 1, 1, -116.72, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-04-04', 2, 3, 5, 13, -276.89, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-04-13', 3, 9, 3, 7, -77.34, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-02-02', 2, 7, 2, 5, 499.47, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-03-01', 3, 1, 1, 3, 70.93, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-10-04', 2, 3, 1, 2, -196.69, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-03-16', 2, 7, 1, 2, 102.89, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-03-30', 3, 8, 2, 6, 655.32, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-07-21', 2, 3, 5, 14, -690.18, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-08-31', 2, 1, 5, 15, -539.95, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-10-29', 1, 6, 1, 2, 13.28, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-04-20', 1, 7, 5, 13, -728.25, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-05-23', 1, 9, 5, 13, 379.63, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-08-16', 2, 9, 5, 13, -689.13, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-09-28', 1, 3, 5, 15, -111.65, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-03-01', 2, 10, 2, 6, -700.69, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-05-13', 1, 1, 1, 1, 227.22, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-04-11', 1, 10, 3, 9, 742.22, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-03-27', 2, 6, 5, 15, -20.49, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-04-03', 3, 3, 5, 14, -364.32, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-09-12', 1, 8, 3, 7, 433.47, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-08-30', 2, 6, 2, 6, -117.76, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-06-02', 3, 2, 3, 9, 535.95, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-01-07', 3, 4, 5, 14, 790.38, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-07-13', 3, 7, 4, 11, 344.6, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-11-02', 3, 9, 2, 6, -312.11, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-12-02', 3, 9, 2, 6, -35.63, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-01-03', 2, 5, 4, 11, -597.29, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-03-16', 1, 8, 3, 7, 619.51, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-04-19', 3, 6, 1, 2, -283.69, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-03-25', 1, 8, 4, 11, 156.43, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-06-30', 3, 4, 2, 5, 384.94, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-12-16', 3, 5, 1, 1, -422.61, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-11-18', 3, 6, 1, 2, 171.62, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-03-20', 3, 5, 1, 3, -661.15, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-03-17', 1, 9, 3, 9, 462.16, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-11-06', 2, 4, 4, 12, -63.78, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-08-07', 1, 5, 3, 8, -6.16, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-03-25', 3, 5, 5, 15, -382.73, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-08-23', 3, 3, 3, 8, 573.52, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-11-28', 2, 6, 4, 12, -526.77, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-11-08', 3, 9, 2, 4, -533.91, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-02-28', 2, 5, 2, 5, 279.59, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-04-03', 1, 2, 2, 5, -325.11, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-05-11', 1, 5, 4, 10, -227.63, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-09-09', 1, 7, 3, 7, -568.25, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-01-27', 3, 2, 3, 8, 132.1, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-08-25', 1, 6, 3, 8, 634.28, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-04-26', 3, 3, 4, 12, -219.23, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-08-01', 2, 9, 4, 10, -462.1, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-09-16', 1, 10, 1, 2, -372.38, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-03-26', 3, 8, 2, 4, 224.3, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-11-05', 3, 5, 2, 4, -564.78, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-07-06', 1, 1, 1, 1, 724.96, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-11-01', 1, 6, 5, 14, 643.82, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-03-08', 1, 7, 3, 7, -725.45, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-02-05', 2, 3, 5, 13, -398.31, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-06-01', 3, 2, 4, 10, 249.09, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-03-08', 2, 10, 2, 6, -440.87, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-03', 3, 8, 5, 13, 455.81, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-02-17', 1, 3, 2, 6, 577.39, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-08-03', 2, 6, 4, 10, 606.04, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-03-02', 1, 5, 2, 5, -55.29, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-10-17', 1, 3, 4, 11, 336.35, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-12-19', 3, 9, 5, 14, 518.34, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-11-08', 3, 2, 5, 15, 507.38, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-03-15', 3, 4, 3, 8, 313.07, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-05-01', 2, 7, 4, 12, -549.56, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-12-29', 1, 6, 2, 5, -770.96, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-02-08', 3, 1, 2, 6, -424.42, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-02-13', 3, 4, 1, 3, 675.79, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-03-07', 3, 7, 2, 5, -13.26, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-07-29', 2, 4, 2, 4, 244.76, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-01-06', 2, 8, 4, 12, -631.4, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-08-07', 2, 8, 3, 7, -387.22, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-02-23', 1, 10, 4, 11, 191.62, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-12-07', 3, 1, 3, 8, 781.87, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-06-12', 2, 2, 2, 5, 216.8, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-06-30', 3, 8, 4, 12, -484.22, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-01-02', 1, 2, 3, 9, 57.94, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-10-04', 2, 7, 1, 3, 579.73, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-09-26', 3, 2, 4, 11, -358.04, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-06-26', 3, 1, 3, 9, 158.43, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-05-10', 2, 9, 2, 4, 545.59, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-12-20', 1, 9, 5, 15, 102.18, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-12-01', 2, 5, 5, 14, -224.13, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-03-11', 1, 5, 3, 8, 699.02, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-03-26', 1, 4, 1, 2, -418.66, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-06-18', 2, 8, 1, 3, 269.83, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-04-04', 2, 3, 5, 15, -550.46, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-01-21', 3, 7, 5, 14, -35.26, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-04-28', 2, 2, 3, 8, -61.39, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-05-28', 2, 9, 1, 3, -618.58, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-05-24', 3, 6, 5, 14, 680.12, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-10-22', 1, 6, 1, 2, 43.79, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-11-17', 1, 2, 1, 2, -241.41, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-10-10', 1, 4, 1, 2, -763.61, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-04-16', 2, 8, 3, 8, -354.76, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-11-06', 3, 6, 3, 8, -68.61, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-04-24', 1, 5, 4, 10, 248.82, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-04-02', 2, 8, 5, 14, -368.26, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-09-12', 1, 3, 2, 4, 486.52, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-10-29', 1, 7, 3, 8, 125.29, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-08-15', 3, 8, 1, 2, 275.16, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-11-05', 1, 3, 2, 6, 131.95, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-04-02', 2, 4, 4, 11, 619.6, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-10-04', 3, 4, 2, 5, 716.72, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-12-24', 3, 2, 2, 5, 767.62, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-02-07', 1, 7, 4, 12, 285.16, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-11-05', 1, 8, 2, 5, 509.4, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-05-23', 2, 9, 3, 9, -375.0, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-09-23', 1, 8, 4, 11, 41.52, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-12-26', 2, 4, 2, 6, 395.76, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-01-31', 2, 4, 3, 9, 505.79, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-10-02', 1, 10, 3, 9, 290.73, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-10-29', 3, 3, 3, 8, -622.61, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-04-16', 3, 4, 1, 3, 243.51, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-05-24', 2, 1, 3, 9, 464.71, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-06-16', 2, 2, 4, 10, -412.12, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-10-12', 2, 7, 1, 3, -259.76, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-04-07', 2, 1, 5, 13, 726.81, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-12-23', 3, 4, 1, 2, -336.57, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-01-10', 1, 9, 3, 7, 66.48, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-06-27', 2, 7, 1, 3, -289.55, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-09-21', 3, 5, 2, 5, -745.15, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-11-05', 1, 9, 4, 11, 245.97, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-11-25', 1, 1, 2, 5, -488.07, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-04-02', 1, 10, 5, 15, 779.4, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-10-26', 3, 1, 5, 14, -707.94, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-11-01', 1, 9, 3, 8, 156.78, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-03-15', 1, 5, 3, 7, -779.3, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-10-10', 1, 10, 1, 2, 188.52, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-11-06', 1, 10, 5, 15, 229.1, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-11-28', 3, 5, 4, 11, 152.37, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-11-21', 1, 6, 2, 5, 490.32, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-10-11', 2, 5, 1, 1, 733.47, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-01-23', 1, 1, 1, 1, 341.95, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-04-12', 2, 10, 4, 10, 336.93, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-05-03', 2, 5, 3, 8, -358.06, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-07-21', 2, 10, 4, 12, 592.5, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-04-14', 3, 4, 5, 15, 754.61, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-05-11', 2, 5, 5, 13, -186.61, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-09-24', 2, 9, 1, 3, 609.57, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-01-06', 3, 6, 2, 4, 154.62, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-10-08', 3, 4, 5, 15, 602.97, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-04-09', 3, 7, 1, 3, 301.28, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-02', 3, 6, 1, 3, 327.27, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-08-19', 2, 1, 4, 12, -779.53, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-10-19', 2, 2, 1, 1, 446.48, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-03-07', 1, 6, 1, 3, 129.13, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-01-12', 3, 8, 4, 12, 541.74, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-04-20', 3, 9, 5, 13, -571.46, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-06-28', 3, 8, 5, 13, -85.81, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-11-14', 2, 7, 2, 4, 143.05, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-02-09', 1, 5, 5, 14, 799.96, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-10-06', 3, 3, 5, 14, -108.54, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-11-16', 2, 1, 5, 14, -36.76, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-07-04', 3, 2, 2, 6, -82.95, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-01-13', 2, 10, 5, 13, -9.48, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-02-14', 3, 6, 1, 3, -254.59, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-06-24', 3, 3, 2, 5, 534.25, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-06-03', 2, 5, 5, 15, -571.46, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-07-28', 3, 9, 4, 11, -63.54, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-09-14', 2, 6, 4, 11, 350.16, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-06-05', 1, 9, 2, 6, -279.84, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-08-10', 3, 7, 1, 1, 10.72, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-03-24', 2, 9, 1, 2, 798.02, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-02-24', 1, 6, 1, 3, -137.72, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-02-29', 3, 2, 5, 13, -561.83, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-06-29', 2, 2, 4, 10, -210.8, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-02-25', 2, 6, 4, 11, -453.62, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-08-30', 2, 1, 3, 7, 361.07, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-09-15', 3, 6, 3, 7, -695.91, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-06-30', 3, 1, 3, 8, 709.21, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-06-14', 2, 6, 4, 12, -72.31, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-05-18', 1, 3, 1, 2, 24.3, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-05-17', 2, 9, 1, 1, -515.09, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-02-08', 2, 3, 5, 14, 520.89, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-09-10', 1, 3, 3, 9, -223.6, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-06-24', 2, 10, 3, 7, -791.78, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-03-13', 2, 5, 4, 11, -643.87, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-06-15', 2, 8, 2, 6, -145.65, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-02-03', 1, 9, 1, 3, 107.92, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-10-31', 3, 10, 5, 14, 362.92, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-11-04', 2, 6, 2, 4, 244.88, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-05-11', 1, 4, 3, 9, 531.14, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-02-28', 1, 9, 2, 5, 496.33, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-12-15', 2, 6, 1, 1, -213.51, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-11-07', 1, 6, 4, 11, -705.8, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-07-17', 3, 6, 5, 14, -534.5, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-05-09', 2, 9, 3, 9, 620.92, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-07-12', 3, 2, 5, 14, 357.61, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-11-02', 1, 10, 3, 8, -403.94, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-04-15', 2, 10, 4, 10, 787.4, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-08-31', 1, 9, 5, 13, 534.47, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-11-18', 1, 3, 2, 5, 79.78, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-09-20', 1, 7, 2, 5, 759.73, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-11-17', 1, 10, 2, 6, -406.92, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-01-11', 3, 6, 5, 14, 795.63, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-11-25', 2, 9, 1, 2, -500.91, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-05-06', 3, 2, 5, 14, 219.66, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-05-13', 1, 6, 3, 7, -245.8, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-10-16', 2, 10, 1, 3, 75.31, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-12-21', 2, 3, 5, 15, -496.26, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-04-12', 3, 5, 4, 10, -164.01, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-10-22', 3, 10, 5, 13, -270.39, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-04-26', 2, 4, 2, 6, 572.12, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-10-26', 3, 7, 1, 3, -738.36, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-04-25', 1, 6, 1, 1, -562.33, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-06-28', 3, 7, 4, 10, -192.15, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-10-18', 1, 8, 4, 10, -382.07, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-10-01', 2, 5, 5, 15, 92.88, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-02-03', 1, 3, 1, 1, -723.19, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-09-08', 2, 5, 1, 3, -702.69, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-06-04', 2, 4, 4, 10, -168.91, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-05-28', 3, 8, 1, 2, -161.89, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-12-26', 2, 5, 5, 15, -779.43, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-11-22', 2, 5, 1, 2, 50.86, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-05-28', 1, 1, 3, 7, -789.93, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-10-14', 2, 5, 4, 10, 682.17, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-01-25', 3, 2, 3, 9, 626.47, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-02-14', 3, 3, 4, 10, -114.2, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-10-04', 3, 8, 2, 5, 202.82, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-12-26', 3, 8, 5, 14, 216.33, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-09-18', 2, 2, 3, 7, 672.52, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-04-15', 1, 5, 5, 14, 129.99, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-09-27', 2, 10, 3, 9, -550.3, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-10-21', 1, 1, 2, 4, -137.22, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-10-17', 2, 2, 1, 1, -188.16, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-04-27', 3, 10, 1, 2, 258.51, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-06-24', 2, 7, 4, 12, -558.27, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-08-13', 1, 4, 5, 13, 174.07, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-12-07', 3, 5, 1, 2, -703.78, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-01-09', 1, 6, 3, 9, 191.36, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-08-26', 3, 4, 5, 15, -610.93, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-05-23', 3, 3, 1, 3, 441.81, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-09-10', 2, 2, 3, 7, -170.59, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-07-09', 2, 6, 4, 10, 234.03, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-12-25', 3, 1, 3, 8, -312.59, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-01-16', 2, 6, 1, 3, 546.75, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-05-03', 3, 5, 3, 8, 324.75, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-07-04', 2, 10, 3, 7, 762.32, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-09-18', 2, 9, 1, 1, -390.3, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-07-13', 3, 2, 4, 11, -307.56, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-03-23', 1, 6, 3, 7, -157.71, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-07-09', 2, 9, 2, 5, -716.63, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-08-16', 1, 6, 5, 15, 296.93, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-09-06', 1, 10, 1, 1, 22.38, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-10-19', 2, 3, 5, 15, -193.4, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-07-28', 1, 5, 3, 9, 298.12, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-09-30', 2, 6, 5, 13, -42.16, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-01-20', 1, 4, 2, 6, -442.63, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-11-10', 2, 7, 4, 10, 572.85, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-06-25', 1, 4, 3, 7, -50.3, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-04-14', 2, 4, 4, 10, 118.41, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-08-18', 1, 6, 2, 5, 14.13, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-01-29', 2, 9, 4, 10, -620.03, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-03-07', 3, 4, 1, 1, -407.06, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-02-22', 1, 4, 1, 3, -347.51, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-06-06', 1, 9, 5, 13, -362.47, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-02-04', 2, 6, 1, 2, -162.27, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-08-18', 2, 3, 3, 7, 122.76, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-08-01', 2, 2, 1, 1, 178.69, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-08-19', 2, 8, 4, 10, 22.49, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-10-07', 1, 4, 2, 6, -154.01, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-05-18', 2, 2, 3, 8, -408.52, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-01-16', 1, 7, 5, 14, -652.16, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-05-08', 1, 8, 4, 11, -381.27, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-01-23', 1, 7, 1, 1, -611.47, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-07-01', 3, 3, 5, 14, 679.56, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-09-04', 1, 8, 5, 15, 175.9, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-06-06', 2, 3, 3, 8, 103.31, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-03-13', 2, 7, 3, 8, 146.81, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-12-20', 2, 9, 4, 12, 303.84, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-03-02', 2, 7, 5, 14, 204.05, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-06-28', 3, 2, 1, 3, 738.35, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-06-29', 2, 2, 1, 3, 452.6, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-09-22', 3, 10, 1, 1, 283.37, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-06-28', 1, 3, 1, 3, 225.32, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-05-26', 3, 9, 2, 5, -795.23, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-03-01', 2, 8, 4, 10, -139.76, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-10-24', 1, 3, 5, 13, 483.02, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-07-20', 1, 4, 1, 2, -690.41, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-11-30', 2, 3, 5, 13, 329.02, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-03-26', 2, 9, 5, 15, -491.83, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-08-21', 1, 10, 5, 14, -650.51, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-02-05', 2, 5, 1, 1, 684.38, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-06-23', 3, 4, 3, 8, 431.8, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-09-22', 2, 6, 3, 9, -508.02, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-08-15', 1, 1, 1, 2, 591.5, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-12-10', 2, 4, 2, 4, -349.62, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-02-24', 3, 3, 2, 4, -274.5, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-01-22', 1, 2, 3, 9, -205.17, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-09-26', 3, 1, 4, 12, 391.77, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-11-25', 1, 4, 4, 12, 707.33, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-04-12', 2, 2, 4, 10, -626.82, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-10-25', 3, 3, 1, 1, 42.07, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-01-02', 1, 3, 4, 11, -108.9, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-09-24', 3, 7, 4, 12, -376.8, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-05-10', 2, 2, 4, 12, -585.23, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-08-26', 1, 3, 4, 12, 103.25, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-04-15', 2, 10, 1, 2, -18.62, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-06-01', 1, 9, 1, 3, 317.97, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-06-13', 3, 9, 3, 9, 743.53, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-09-12', 3, 4, 2, 6, -101.12, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-11-30', 3, 5, 3, 9, -455.93, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-06-03', 3, 1, 5, 15, -557.58, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-08-27', 1, 10, 3, 8, 108.01, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-12-06', 3, 6, 3, 9, -634.17, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-03-20', 3, 4, 1, 1, 429.45, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-08-18', 1, 4, 4, 10, -74.16, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-05-10', 2, 4, 5, 13, 464.26, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-10-08', 2, 4, 4, 10, -118.99, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-03-03', 3, 7, 2, 4, -642.46, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-03-27', 1, 3, 3, 7, -604.47, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-09-09', 2, 2, 2, 4, 787.03, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-06-12', 1, 7, 4, 11, -471.81, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-09-24', 1, 2, 4, 12, -383.72, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-09-05', 2, 4, 3, 7, 69.34, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-25', 3, 3, 3, 9, -550.52, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-11-08', 2, 5, 5, 13, -512.51, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-10-06', 2, 9, 5, 13, 591.96, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-12-22', 3, 3, 2, 4, 26.52, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-12-05', 2, 3, 3, 8, 326.07, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-08-24', 2, 10, 4, 10, -8.65, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-11-18', 1, 3, 2, 4, -248.12, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-06-13', 2, 1, 5, 14, 278.21, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-12-26', 1, 1, 2, 4, 5.11, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-11-03', 1, 4, 3, 8, -616.36, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-11-27', 2, 10, 2, 5, 557.41, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-02-16', 3, 6, 3, 8, 767.6, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-05-02', 2, 2, 3, 9, 457.66, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-10-23', 3, 9, 5, 14, -767.98, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-08-28', 2, 7, 5, 13, -563.21, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-06-14', 1, 1, 2, 4, 712.08, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-02-29', 3, 8, 5, 14, -658.92, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-08-21', 1, 4, 3, 7, 212.63, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-06-19', 3, 2, 1, 1, 356.45, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-12-29', 3, 4, 5, 13, -666.64, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-11-17', 2, 10, 5, 14, 76.14, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-08-10', 2, 5, 4, 12, -420.42, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-04-13', 1, 2, 5, 14, 699.16, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-12-29', 1, 1, 2, 5, 592.17, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-08-10', 3, 1, 3, 7, -338.95, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-09-24', 2, 2, 2, 5, 759.0, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-11-22', 1, 10, 1, 1, -390.17, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-12-18', 2, 6, 5, 13, 521.87, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-12-31', 1, 10, 5, 15, 475.68, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-09-16', 3, 2, 4, 10, -550.61, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-05-28', 1, 1, 5, 14, 36.91, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-11-28', 3, 9, 4, 11, -237.28, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-11-04', 2, 10, 4, 10, -669.69, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-01-17', 3, 7, 4, 12, 24.24, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-12-30', 3, 4, 2, 5, 510.3, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-08-09', 2, 4, 5, 14, -309.56, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-08-29', 3, 1, 4, 11, 379.99, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-04-30', 1, 10, 3, 9, 727.86, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-02-17', 1, 10, 5, 14, -176.71, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-02-14', 3, 8, 1, 2, 694.17, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-08-26', 1, 10, 4, 12, 148.72, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-10-17', 1, 10, 2, 4, -273.86, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-09-08', 1, 8, 1, 1, -122.19, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-09-11', 1, 3, 4, 11, 693.37, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-10-11', 2, 2, 3, 7, 193.73, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-10-01', 2, 6, 5, 15, -51.22, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-02-12', 2, 1, 1, 1, -267.64, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-01-19', 3, 6, 4, 10, 705.34, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-09-06', 1, 7, 1, 1, -541.2, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-10-23', 2, 10, 5, 15, 732.66, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-10-17', 2, 7, 1, 3, -643.43, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-12-29', 3, 3, 3, 9, -350.8, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-11', 2, 6, 5, 15, -462.71, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-06-18', 1, 6, 2, 6, 378.92, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-04-20', 1, 3, 2, 5, 175.98, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-08-17', 2, 1, 3, 8, -760.1, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-04-27', 2, 1, 3, 8, 158.0, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-10-13', 1, 1, 2, 4, 628.99, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-02-20', 2, 7, 1, 3, -23.36, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-10-08', 3, 6, 4, 11, 183.64, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-06-28', 1, 9, 5, 15, -361.36, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-09-01', 1, 7, 2, 6, 338.05, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-11-09', 1, 6, 2, 4, -153.55, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-10-03', 1, 1, 5, 13, 410.66, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-07-10', 1, 7, 4, 12, 262.77, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-09-21', 1, 6, 3, 9, -337.83, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-07-20', 3, 10, 2, 6, -769.2, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-06-11', 2, 2, 4, 11, -120.2, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-11-25', 2, 9, 4, 12, -781.93, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-04-18', 2, 8, 2, 5, -407.96, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-11-09', 3, 5, 3, 9, -83.22, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-03-17', 3, 5, 5, 13, -28.95, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-09-04', 1, 6, 5, 14, -73.14, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-05-18', 3, 8, 1, 1, 711.91, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-10-21', 3, 10, 1, 3, -667.14, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-01-09', 1, 5, 4, 10, -239.44, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-11-28', 3, 7, 3, 7, 450.5, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-06-18', 3, 9, 1, 1, -318.52, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-01-13', 2, 7, 4, 12, 537.87, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-12-03', 1, 6, 1, 3, -372.91, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-04-25', 2, 1, 3, 9, -700.92, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-09-30', 2, 10, 3, 8, -723.18, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-03-14', 3, 5, 4, 12, -589.07, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-05-06', 2, 5, 1, 3, 191.5, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-10-15', 3, 4, 4, 10, -650.4, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-11-23', 2, 5, 2, 5, -622.12, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-08-18', 3, 9, 3, 8, -46.21, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-03-25', 3, 6, 5, 15, 368.05, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-07-24', 1, 5, 1, 2, 564.42, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-06-20', 3, 1, 5, 13, 657.08, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-09-12', 3, 6, 3, 9, -591.83, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-08-11', 1, 2, 2, 5, -97.57, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-04-10', 2, 1, 5, 13, 426.72, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-01-27', 3, 8, 2, 4, 599.32, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-10-30', 3, 4, 4, 11, 462.67, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-02-18', 1, 6, 2, 6, -655.21, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-03-06', 2, 4, 2, 6, 385.47, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-02-09', 1, 8, 3, 8, -218.14, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-02-06', 3, 10, 2, 5, 35.54, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-08-31', 1, 6, 5, 15, -547.7, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-11-30', 3, 5, 3, 8, -694.64, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-04-09', 2, 5, 2, 5, 673.43, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-03-25', 3, 10, 4, 11, -705.4, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-11-07', 2, 5, 3, 7, 389.25, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-11-04', 1, 7, 4, 10, 799.16, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-08-07', 3, 6, 2, 4, 209.98, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-08-24', 2, 6, 1, 1, 439.51, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-07-25', 2, 5, 1, 1, -528.22, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-09-30', 3, 9, 1, 1, 677.96, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-11-30', 3, 8, 2, 4, 492.04, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-11-23', 3, 2, 1, 3, 497.35, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-10-29', 2, 6, 3, 9, -740.47, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-01-02', 1, 4, 1, 2, -615.58, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-10-15', 3, 8, 2, 5, 217.12, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-05-19', 1, 6, 5, 13, 187.26, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-07-23', 1, 9, 4, 11, -175.64, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-09-15', 1, 6, 2, 4, 136.61, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-04-20', 2, 6, 5, 15, 174.8, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-05-19', 3, 10, 3, 9, -528.63, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-02-26', 2, 7, 4, 11, -648.93, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-05-20', 1, 5, 1, 2, 403.62, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-09-08', 2, 3, 4, 11, -35.78, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-01-11', 1, 4, 1, 1, 649.08, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-10-16', 1, 2, 4, 11, -101.7, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-04-01', 3, 9, 5, 14, -154.31, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-07-13', 3, 2, 4, 12, 125.31, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-03-15', 1, 3, 1, 1, -88.38, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-03-29', 2, 3, 1, 2, 75.88, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-01-18', 2, 9, 1, 1, -97.66, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-01-09', 3, 8, 4, 11, 126.78, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-01-14', 1, 8, 5, 14, -112.31, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-12-10', 2, 6, 1, 2, -701.35, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-06-17', 1, 2, 4, 12, -512.48, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-03-08', 1, 5, 3, 8, 187.42, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-02-17', 2, 1, 3, 9, -467.6, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-12-09', 2, 10, 4, 10, 352.84, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-06-17', 3, 3, 5, 15, -797.9, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-04-19', 2, 9, 3, 9, 49.89, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-09-09', 1, 9, 1, 2, -501.32, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-09-16', 3, 3, 3, 7, -61.48, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-12-29', 1, 7, 5, 13, -27.59, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-01-27', 1, 4, 3, 9, -174.65, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-06-03', 1, 9, 2, 6, -647.25, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-10-01', 2, 10, 1, 2, -197.7, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-08-23', 1, 5, 5, 14, 678.11, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-04-09', 2, 8, 1, 1, 551.81, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-01-29', 3, 9, 4, 10, 298.17, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-01-25', 3, 10, 1, 2, -169.99, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-02-10', 2, 9, 4, 11, 778.16, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-11-29', 1, 8, 5, 14, 423.01, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-09-29', 2, 10, 1, 1, -119.79, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-06-13', 1, 7, 5, 13, 692.23, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-09-29', 3, 3, 4, 11, 691.83, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-12-15', 1, 6, 1, 1, 686.1, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-05-01', 3, 7, 4, 12, 188.56, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-07-09', 2, 10, 4, 11, -51.21, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-11-18', 3, 2, 4, 12, 394.39, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-08-17', 1, 2, 4, 11, -403.23, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-08-11', 1, 9, 2, 5, 121.59, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-09-21', 3, 3, 2, 6, -580.65, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-05-26', 1, 10, 4, 12, 545.7, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-08-22', 2, 5, 1, 1, -54.17, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-11-18', 3, 10, 2, 6, -101.73, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-03-12', 3, 2, 2, 6, -474.0, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-11-24', 3, 4, 5, 15, -729.4, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-09-14', 2, 10, 1, 2, 264.99, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-07-30', 1, 2, 1, 3, 428.89, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-03-21', 3, 2, 1, 1, 432.18, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-12-03', 1, 2, 5, 13, -161.63, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-01-26', 3, 1, 3, 7, -228.73, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-10-06', 2, 10, 1, 2, -738.9, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-02-13', 2, 10, 5, 13, -381.7, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-07-08', 1, 4, 2, 6, -572.76, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-09-15', 2, 10, 2, 5, 321.19, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-06-30', 2, 5, 3, 9, -101.26, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-10-21', 1, 2, 4, 10, -133.18, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-08-08', 3, 5, 3, 7, 44.92, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-06-06', 2, 6, 4, 10, -236.89, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-09-27', 2, 6, 4, 12, -82.89, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-11-27', 1, 6, 5, 15, 482.5, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-03-28', 3, 9, 4, 12, -329.07, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-03-08', 1, 3, 1, 2, 770.28, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-02-13', 3, 10, 4, 10, 135.51, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-02-28', 2, 6, 2, 5, 730.09, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-09-20', 3, 9, 2, 5, -179.72, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-06-29', 2, 3, 5, 13, 43.5, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-01-23', 3, 1, 5, 14, 729.23, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-03-10', 1, 7, 4, 11, 563.6, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-04-09', 1, 3, 2, 4, 646.52, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-05-17', 2, 1, 2, 4, -767.51, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-11-20', 3, 9, 4, 10, -404.94, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-01-14', 3, 1, 1, 1, 292.69, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-07-23', 1, 5, 1, 3, -773.78, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-06-21', 2, 10, 2, 6, 682.64, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-03-30', 1, 4, 3, 9, 218.39, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-10-07', 1, 5, 5, 13, -394.74, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-02-07', 2, 4, 1, 3, -717.74, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-03-01', 3, 7, 2, 6, 290.1, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-04-17', 2, 10, 1, 2, 451.88, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-11-24', 3, 10, 2, 6, 492.83, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-04-06', 3, 7, 1, 2, 587.23, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-10-02', 2, 5, 2, 6, -712.96, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-05-15', 1, 4, 2, 6, -472.21, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-01-30', 3, 6, 2, 5, 193.92, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-03-20', 2, 5, 2, 4, -619.4, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-01-25', 1, 1, 5, 14, -267.19, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-11-27', 1, 1, 5, 14, -626.66, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-08-28', 3, 6, 2, 4, -388.27, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-11-13', 3, 3, 1, 3, -325.43, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-04-28', 1, 2, 3, 7, 261.63, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-08-30', 2, 3, 4, 12, -158.71, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-04-09', 2, 9, 1, 2, -16.02, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-06-09', 3, 9, 2, 4, 550.45, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-03-30', 1, 2, 2, 5, -82.88, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-02-22', 3, 6, 4, 10, 153.08, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-06-21', 2, 1, 4, 10, 541.1, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-11-13', 3, 2, 4, 12, -752.47, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-05-30', 1, 1, 1, 1, 486.56, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-09-08', 2, 7, 3, 9, -393.16, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-02-10', 2, 9, 4, 10, -500.88, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-01-13', 2, 3, 1, 1, 432.86, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-12-26', 1, 1, 2, 5, 760.71, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-03-12', 1, 4, 4, 12, -749.23, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-02-05', 3, 10, 2, 6, -472.66, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-10-21', 3, 9, 4, 10, -161.69, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-04-28', 1, 3, 3, 8, 794.01, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-09-18', 2, 5, 2, 5, -661.49, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-01-14', 1, 4, 1, 2, -482.04, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-05-01', 3, 6, 1, 1, -429.14, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-02-10', 1, 4, 1, 2, -344.81, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-02-09', 3, 4, 4, 11, 197.88, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-04-11', 1, 8, 1, 1, 145.32, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-05-01', 2, 10, 5, 13, -75.88, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-03-05', 3, 4, 1, 3, 709.5, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-07-17', 1, 9, 1, 2, 535.98, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-05-14', 3, 1, 2, 5, -542.43, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-10-05', 3, 2, 4, 10, 732.17, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-04-20', 1, 1, 5, 15, -65.87, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-11-24', 2, 1, 1, 2, 730.02, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-06-16', 1, 8, 2, 4, -675.17, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-28', 3, 3, 4, 11, -100.01, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-09-24', 1, 2, 1, 3, 724.41, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-11-13', 2, 1, 2, 6, 254.35, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-09-02', 2, 10, 5, 14, -65.91, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-03-04', 3, 5, 1, 3, 225.93, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-12-06', 1, 9, 1, 1, -318.37, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-03-03', 3, 10, 2, 6, 729.63, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-09-25', 2, 10, 5, 14, -497.47, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-08-02', 2, 3, 2, 6, 767.22, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-04-13', 1, 2, 4, 11, 461.4, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-12-27', 3, 5, 1, 2, -455.67, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-03-22', 2, 9, 5, 15, 127.86, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-06-01', 2, 1, 4, 10, 506.21, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-08-09', 3, 4, 3, 9, 6.26, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-05-18', 1, 3, 2, 4, 36.52, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-08-06', 1, 8, 3, 7, -691.93, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-02-21', 1, 10, 3, 8, 151.71, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-04-04', 3, 5, 2, 6, 158.1, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-09-05', 1, 5, 4, 10, 572.88, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-06', 3, 10, 5, 15, -736.5, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-11-28', 1, 4, 2, 5, 266.94, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-10-12', 3, 6, 2, 5, 574.29, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-10-24', 3, 10, 5, 14, -16.08, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-01-07', 3, 9, 2, 4, -158.71, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-03-12', 3, 8, 5, 13, 217.3, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-10-18', 3, 1, 2, 5, -419.45, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-10-15', 3, 8, 4, 12, -228.89, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-01-17', 3, 9, 2, 6, -273.01, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-01-03', 2, 8, 2, 4, 90.98, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-11-17', 2, 1, 1, 1, 299.99, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-08-31', 1, 5, 5, 15, -356.83, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-03-22', 1, 5, 4, 11, 28.45, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-03-30', 1, 1, 2, 5, 28.26, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-12-13', 3, 5, 2, 4, -554.16, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-01-08', 2, 6, 2, 6, -259.47, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-07-01', 2, 4, 4, 10, -516.31, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-07-12', 3, 3, 1, 2, -708.53, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-12-08', 3, 9, 2, 5, -160.07, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-05-22', 2, 6, 3, 8, -492.89, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-06-05', 3, 2, 3, 7, 326.85, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-06-06', 1, 7, 4, 10, 95.98, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-01-20', 3, 8, 3, 8, -215.57, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-01-07', 3, 3, 1, 3, 325.87, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-06-09', 3, 4, 4, 10, 703.65, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-08-27', 3, 3, 4, 12, -610.44, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-10-07', 2, 2, 2, 6, -407.7, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-02-12', 2, 2, 1, 3, 167.46, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-12-12', 2, 8, 4, 11, 426.2, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-10-26', 1, 8, 5, 13, -81.63, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-02-11', 1, 1, 2, 5, -733.2, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-08-20', 2, 7, 5, 15, 171.7, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-06-05', 2, 3, 1, 1, 151.71, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-10-28', 1, 7, 1, 1, -94.12, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-12-08', 1, 8, 2, 6, 725.19, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-06-14', 1, 8, 2, 4, 798.11, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-09-19', 1, 8, 4, 11, -328.68, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-07-11', 3, 4, 3, 8, -324.31, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-12-27', 3, 2, 3, 8, 252.76, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-07-05', 1, 8, 1, 3, -104.65, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-11-24', 2, 2, 3, 9, -254.3, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-12-23', 2, 2, 2, 5, 97.98, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-05-03', 1, 9, 2, 6, 524.36, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-03-15', 3, 5, 2, 4, -140.47, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-08-12', 2, 3, 2, 4, 532.04, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-13', 2, 7, 5, 15, 349.77, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-03-19', 1, 7, 1, 3, 436.49, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-05-22', 2, 5, 5, 15, -161.45, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-10-01', 1, 10, 3, 7, 357.35, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-09-14', 2, 4, 2, 5, 681.88, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-01-16', 2, 10, 3, 7, -161.51, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-10-22', 1, 5, 3, 7, 785.84, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-01-07', 2, 5, 5, 15, 252.36, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-02-27', 3, 6, 3, 8, 211.39, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-01-01', 3, 1, 2, 4, 198.44, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-02-01', 1, 6, 3, 8, -518.99, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-02-08', 1, 1, 2, 5, 256.93, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-07-20', 3, 8, 2, 5, -297.2, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-07-06', 3, 4, 5, 14, 246.13, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-02-24', 1, 5, 5, 15, 230.3, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-07-16', 1, 7, 5, 15, -352.66, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-09-11', 2, 9, 3, 9, -237.83, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-05-27', 3, 3, 1, 2, -458.75, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-02-21', 3, 10, 3, 9, 297.41, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-11-16', 2, 8, 3, 9, -510.7, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-08-07', 3, 4, 5, 13, 691.89, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-05-28', 1, 3, 5, 13, 659.35, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-04-03', 3, 7, 2, 5, 637.88, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-09-08', 2, 6, 4, 11, -40.25, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-03-29', 3, 7, 1, 1, -254.5, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-07-02', 3, 2, 5, 13, 309.87, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-11-30', 1, 5, 3, 8, -123.46, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-12-22', 2, 6, 2, 5, 205.94, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-03', 3, 5, 5, 14, -675.41, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-05-06', 3, 10, 5, 13, 771.24, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-10-06', 1, 6, 4, 10, -604.42, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-12-25', 3, 9, 5, 13, -189.1, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-09-28', 3, 9, 1, 3, 638.79, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-07-19', 2, 6, 3, 8, -397.86, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-07-31', 3, 7, 3, 8, 52.3, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-10-30', 2, 2, 1, 1, 461.95, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-09-16', 2, 4, 2, 6, 726.91, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-10-18', 3, 6, 1, 2, 204.63, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-05-14', 3, 9, 3, 9, -179.64, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-02-17', 2, 9, 1, 3, 599.66, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-05-06', 2, 1, 3, 8, 84.12, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-01-06', 1, 8, 2, 4, 644.09, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-09-19', 1, 9, 2, 4, 506.52, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-07-13', 2, 5, 5, 14, 200.27, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-02-11', 2, 7, 3, 8, -521.59, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-10-19', 2, 4, 3, 7, 461.24, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-09-10', 3, 2, 4, 11, -157.72, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-12-12', 3, 5, 2, 6, 697.88, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-01', 2, 8, 2, 5, 648.65, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-07-17', 1, 5, 1, 1, -54.64, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-01-04', 3, 4, 5, 14, 503.23, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-08-31', 2, 1, 5, 15, 184.58, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-04-22', 2, 7, 2, 4, -469.28, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-08-23', 3, 9, 2, 5, 200.96, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-09-08', 3, 3, 1, 1, -646.91, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-08-30', 3, 7, 2, 5, 60.49, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-12-14', 3, 7, 2, 6, 401.59, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-12-10', 2, 7, 2, 4, -301.86, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-01-17', 2, 2, 1, 2, 64.16, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-03-06', 1, 6, 5, 13, -466.77, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-04-22', 1, 2, 3, 7, -782.1, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-12-17', 1, 4, 2, 6, -777.33, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-11-07', 1, 7, 1, 2, -208.94, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-12-25', 3, 2, 5, 13, 193.43, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-02-09', 3, 6, 2, 4, 544.14, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-05-06', 1, 6, 2, 6, 71.07, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-09-11', 2, 4, 2, 4, -743.5, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-05-31', 2, 8, 2, 5, 514.86, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-01-06', 1, 4, 1, 1, -596.3, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-09-22', 3, 4, 3, 8, 781.92, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-09-03', 2, 4, 5, 13, -192.92, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-10-28', 2, 2, 4, 11, 620.37, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-04-11', 3, 3, 2, 5, -416.1, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-07-06', 3, 5, 5, 15, 331.14, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-21', 1, 6, 1, 2, -85.84, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-12-16', 1, 10, 3, 9, 568.76, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-09-23', 3, 8, 5, 13, -118.86, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-02-27', 2, 9, 4, 11, 703.8, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-02-09', 2, 1, 2, 4, 445.96, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-04-21', 1, 6, 3, 9, 660.3, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-07-29', 1, 8, 2, 5, 41.2, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-05-12', 2, 7, 2, 5, -559.05, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-08-31', 3, 7, 3, 8, -458.14, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-08-28', 1, 4, 4, 11, -641.57, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-11-02', 1, 9, 1, 2, 299.95, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-03-20', 1, 8, 2, 5, -747.1, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-10-11', 1, 10, 5, 15, 173.59, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-01-02', 3, 2, 4, 11, -105.21, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-02-12', 1, 10, 3, 9, 477.21, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-06-20', 1, 4, 5, 13, -515.79, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-03-31', 2, 2, 4, 12, 486.24, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-12-27', 3, 6, 1, 2, -166.9, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-01-08', 2, 5, 1, 1, -127.88, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-09-15', 2, 4, 2, 6, -788.61, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-11-06', 1, 6, 4, 12, 722.86, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-07-26', 2, 3, 4, 12, -14.92, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-05-24', 2, 3, 2, 5, -468.93, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-04-28', 3, 5, 1, 2, -531.36, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-12-07', 3, 1, 5, 14, 136.22, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-07-29', 3, 8, 3, 7, 8.99, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-09-03', 3, 4, 3, 9, -520.23, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-11-20', 3, 3, 3, 8, 325.07, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-02-11', 1, 5, 5, 15, -642.06, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-08-05', 3, 9, 3, 8, 164.43, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-08-03', 2, 5, 4, 12, -157.09, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-12-09', 3, 9, 4, 11, 609.34, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-04-17', 1, 3, 2, 4, 323.97, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-06-28', 2, 4, 2, 5, -106.71, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-03-01', 2, 9, 4, 12, 191.33, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-05-23', 2, 10, 2, 5, 321.09, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-08-12', 2, 3, 5, 13, -337.66, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-03-01', 3, 10, 2, 5, -786.74, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-11-23', 1, 4, 3, 9, 652.24, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-04-28', 3, 1, 2, 6, -648.24, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-06-27', 1, 8, 3, 8, -699.71, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-04-06', 3, 4, 3, 9, 670.44, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-08-13', 2, 3, 1, 1, -403.45, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-01-23', 1, 6, 5, 15, -702.76, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-10-16', 3, 4, 4, 10, 101.47, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-06-10', 3, 9, 1, 3, -636.28, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-10-03', 3, 3, 2, 6, 299.04, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-22', 1, 8, 1, 3, -310.36, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-04-21', 2, 1, 2, 4, -659.78, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-11-19', 2, 6, 1, 3, 598.13, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-01-18', 1, 7, 2, 4, -513.21, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-11-23', 2, 5, 1, 3, -456.7, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-02-26', 1, 2, 3, 9, 209.21, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-07-12', 3, 5, 5, 15, 466.45, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-03-19', 2, 6, 4, 11, 584.2, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-16', 2, 5, 1, 3, -58.66, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-10-14', 3, 9, 1, 2, -197.14, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-06-04', 3, 9, 4, 11, -158.19, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-06-11', 3, 4, 4, 12, 460.26, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-05-12', 1, 7, 1, 3, 94.16, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-12-12', 2, 4, 2, 5, -90.63, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-09-04', 1, 9, 3, 8, -777.65, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-08-22', 2, 2, 4, 10, -137.62, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-03-29', 2, 4, 5, 14, -575.1, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-05-18', 1, 6, 5, 13, -219.6, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-05-07', 2, 9, 2, 4, 402.79, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-01-09', 1, 3, 2, 5, -798.96, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-12-14', 2, 1, 1, 2, 634.89, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-09-06', 2, 6, 4, 10, -486.44, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-08-27', 2, 6, 5, 15, -799.81, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-11-21', 2, 8, 4, 12, 538.35, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-07-04', 1, 7, 3, 8, -60.35, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-12-19', 1, 9, 2, 6, -668.84, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-04-20', 1, 4, 2, 5, 68.87, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-10-19', 2, 9, 4, 10, 772.24, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-10-10', 2, 5, 5, 14, -380.21, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-03-15', 3, 4, 1, 3, 520.24, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-08-06', 2, 1, 5, 13, 596.68, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-11-03', 2, 9, 5, 15, -405.21, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-03-14', 3, 7, 3, 9, -421.17, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-10-18', 2, 6, 3, 7, 678.43, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-10-22', 3, 7, 1, 2, -586.95, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-03-03', 3, 7, 1, 2, 343.8, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-04-20', 3, 4, 5, 15, 789.2, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-01-22', 3, 3, 2, 6, 353.8, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-02-12', 1, 1, 4, 10, -317.4, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-09-07', 2, 9, 2, 5, -728.74, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-05-11', 1, 1, 3, 8, -347.27, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-09-18', 2, 5, 2, 4, -8.78, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-01-08', 3, 10, 2, 5, 383.73, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-05-26', 1, 10, 3, 7, 24.72, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-01-22', 3, 6, 5, 14, -534.72, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-04-01', 1, 3, 5, 15, 707.58, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-07-14', 1, 5, 5, 14, 561.75, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-09-15', 2, 9, 3, 7, 670.33, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-11-23', 3, 7, 2, 5, 725.03, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-11-05', 2, 2, 3, 8, 395.42, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-07-30', 2, 5, 2, 5, 686.87, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-04-20', 1, 10, 4, 12, 596.72, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-04-13', 3, 2, 1, 2, 688.7, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-05-20', 3, 9, 5, 15, 346.69, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-02-15', 2, 8, 2, 6, 635.44, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-09-06', 1, 8, 2, 6, 603.89, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-05-29', 3, 4, 3, 9, -134.31, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-02-11', 2, 3, 5, 14, 491.95, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-11-18', 2, 5, 3, 8, -430.6, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-08-21', 3, 5, 3, 8, -492.01, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-01-12', 2, 10, 1, 2, 707.55, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-09-27', 2, 5, 3, 8, 789.55, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-02-26', 3, 6, 2, 6, -31.46, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-11-11', 2, 3, 2, 5, 567.36, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-09-28', 3, 7, 3, 7, -5.5, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-08-23', 2, 3, 1, 3, 43.21, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-01-30', 3, 8, 1, 1, 761.95, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-03-28', 2, 9, 3, 8, 446.11, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-01-22', 3, 7, 2, 4, -85.85, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-08-23', 1, 8, 5, 15, -115.84, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-03-11', 1, 7, 4, 10, -738.22, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-06-03', 2, 7, 2, 4, -270.5, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-09-18', 2, 4, 5, 14, 395.46, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-01-12', 1, 3, 1, 1, -365.21, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-04-01', 1, 2, 2, 4, 614.43, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-09-15', 1, 6, 2, 5, 95.55, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-06-24', 3, 10, 5, 14, 681.11, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-01-29', 2, 3, 5, 14, 44.24, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-06-28', 1, 2, 1, 3, -489.54, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-12-01', 2, 1, 4, 11, -198.26, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-11-04', 3, 4, 2, 5, -95.3, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-09-01', 3, 10, 5, 15, 180.42, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-11-19', 3, 6, 5, 13, 136.93, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-02-14', 3, 9, 1, 1, -765.51, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-09-27', 3, 3, 1, 1, -206.61, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-01-14', 1, 2, 2, 6, -205.2, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-05-29', 2, 6, 2, 6, -118.49, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-05-25', 2, 3, 1, 2, 325.94, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-10-27', 2, 5, 2, 4, 683.93, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-10-01', 1, 1, 5, 13, -117.74, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-05-30', 2, 3, 3, 9, -126.05, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-06-15', 2, 1, 5, 15, 572.75, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-04-04', 1, 7, 2, 6, 443.8, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-11-09', 3, 6, 2, 5, -559.07, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-12-25', 3, 2, 3, 7, 691.75, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-11-29', 3, 5, 4, 11, -687.36, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-09-21', 1, 7, 5, 14, -370.46, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-02-07', 3, 4, 5, 15, 79.24, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-10-24', 3, 2, 5, 15, -666.42, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-06-09', 3, 10, 4, 12, -797.29, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-03-16', 3, 4, 4, 12, -590.16, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-03-18', 2, 5, 3, 9, -68.5, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-07-22', 2, 8, 4, 12, 228.02, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-12-06', 2, 10, 2, 4, 708.7, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-02-27', 3, 7, 5, 15, 520.77, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-11-15', 1, 3, 3, 8, 624.37, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-07-24', 3, 1, 3, 8, 484.07, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-04-21', 3, 9, 1, 1, -253.2, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-05-29', 2, 3, 2, 4, -148.03, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-07-01', 3, 5, 2, 4, -466.41, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-04-08', 3, 9, 1, 1, 256.65, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-11-11', 2, 5, 2, 5, 88.56, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-03-06', 1, 4, 4, 12, 621.21, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-08-07', 3, 10, 1, 2, 341.1, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-10-08', 3, 8, 2, 4, 375.13, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-10-03', 2, 7, 3, 8, -283.17, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-01-16', 3, 8, 3, 9, -426.09, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-08-29', 3, 4, 5, 14, 640.41, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-01-07', 2, 1, 4, 12, 721.75, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-11-14', 2, 2, 1, 2, -537.24, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-10-02', 1, 8, 3, 7, 176.72, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-08-12', 2, 5, 3, 7, 11.56, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-17', 1, 6, 4, 12, 618.0, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-07', 2, 9, 5, 13, -325.62, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-01-28', 3, 7, 1, 2, -557.48, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-07-09', 1, 7, 1, 2, 131.56, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-10-25', 2, 9, 5, 13, -377.33, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-09-19', 3, 5, 2, 6, -753.24, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-05-10', 2, 1, 5, 14, 700.18, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-09-30', 2, 2, 4, 11, -654.82, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-01-17', 3, 7, 2, 5, 124.63, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-05-03', 3, 10, 3, 9, 402.33, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-09-06', 3, 8, 4, 12, 278.91, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-05-09', 2, 4, 5, 14, -142.35, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-10-30', 1, 1, 1, 2, 142.05, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-02-05', 2, 1, 4, 11, 216.8, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-09-20', 1, 6, 1, 2, 74.11, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-10-26', 1, 5, 4, 10, -516.82, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-07-28', 3, 5, 3, 9, 178.96, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-08-18', 1, 9, 3, 8, -215.44, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-04-23', 1, 1, 3, 8, -315.12, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-03-17', 3, 6, 4, 10, -266.39, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-10-20', 1, 7, 4, 10, 484.54, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-01-14', 2, 9, 3, 7, 303.15, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-09-21', 1, 10, 3, 7, -580.5, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-07-25', 1, 10, 4, 10, -674.67, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-07-04', 2, 5, 1, 2, -214.49, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-10-25', 3, 2, 2, 4, 422.45, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-09-12', 1, 7, 1, 1, -254.84, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-10-18', 1, 9, 3, 9, 778.01, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-10-01', 3, 5, 4, 10, -250.1, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-03-12', 1, 4, 1, 1, -659.56, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-11-07', 1, 5, 3, 8, 214.72, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-02-05', 3, 10, 4, 12, -146.58, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-08-23', 2, 7, 2, 6, 237.58, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-03-17', 2, 10, 1, 2, 80.16, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-02-24', 3, 7, 1, 1, 42.34, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-05-09', 2, 7, 3, 8, -254.99, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-04-19', 1, 6, 5, 14, -461.21, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-01-26', 2, 2, 2, 6, 120.24, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-04-20', 1, 10, 1, 2, 400.67, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-09-02', 3, 4, 2, 6, -270.59, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-08-04', 1, 9, 4, 11, -492.1, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-11-06', 2, 3, 4, 12, -718.15, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-09-21', 3, 8, 4, 10, -525.33, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-03-04', 1, 6, 1, 2, -140.69, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-10-19', 1, 8, 2, 4, 798.47, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-04-12', 1, 5, 2, 5, -361.76, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-05-21', 3, 5, 1, 3, -430.05, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-07-21', 1, 6, 2, 5, -629.79, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-04-21', 2, 5, 5, 15, 791.59, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-09-04', 1, 9, 5, 14, -597.29, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-11-07', 2, 8, 3, 9, -146.04, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-08-20', 1, 1, 4, 11, -290.38, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-01-13', 3, 8, 1, 2, -499.83, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-06-15', 3, 4, 2, 6, -201.64, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-08-03', 1, 7, 3, 9, -643.64, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-08-17', 3, 10, 2, 4, 87.82, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-05-29', 2, 10, 4, 10, 360.17, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-07-16', 2, 9, 1, 3, 294.57, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-01-29', 1, 1, 3, 9, 555.76, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-03-28', 1, 3, 1, 1, 748.19, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-12-16', 1, 4, 4, 12, 284.43, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-08-31', 1, 5, 2, 6, 577.99, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-10-09', 1, 7, 3, 7, -118.42, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-06-19', 1, 9, 2, 5, -670.53, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-12-15', 3, 2, 4, 12, 695.73, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-03-14', 2, 7, 5, 13, 375.26, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-03-27', 1, 8, 3, 8, -632.64, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-12-18', 2, 8, 5, 14, -424.92, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-04-25', 1, 6, 1, 2, -274.63, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-05-01', 2, 9, 2, 4, 443.24, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-09-03', 1, 9, 4, 12, -347.18, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-02-27', 1, 4, 4, 12, -594.56, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-09-24', 1, 9, 3, 7, 570.6, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-10-10', 1, 6, 3, 9, 187.47, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-04-16', 1, 2, 1, 3, 349.94, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-09-17', 1, 7, 4, 10, -641.82, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-08-28', 3, 10, 5, 13, 139.31, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-11', 1, 5, 2, 5, -571.7, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-11-20', 3, 4, 3, 7, -571.41, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-05-20', 3, 10, 5, 14, -384.36, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-12-05', 2, 3, 3, 8, -498.41, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-09-24', 3, 6, 4, 12, 291.55, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-09-11', 1, 2, 5, 13, 129.35, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-06-04', 2, 3, 4, 11, -619.25, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-11-01', 2, 6, 3, 8, 177.84, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-10-18', 3, 1, 3, 7, 741.6, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-05-27', 3, 4, 1, 3, 719.63, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-11-09', 3, 4, 3, 8, -95.3, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-10-25', 2, 4, 5, 13, 205.13, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-05-15', 3, 6, 1, 3, 325.73, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-04-05', 2, 6, 2, 4, -607.46, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-02-10', 1, 10, 1, 1, 337.37, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-08-24', 3, 10, 2, 6, -232.52, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-12-14', 1, 10, 5, 14, -422.43, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-09-18', 1, 3, 4, 12, 465.25, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-12-16', 1, 8, 1, 3, -640.71, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-10-13', 1, 10, 5, 14, -187.52, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-02-18', 3, 4, 5, 13, 395.52, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-01-07', 2, 9, 1, 1, 34.95, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-09-19', 3, 7, 1, 3, -546.73, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-11-02', 3, 7, 2, 4, 646.44, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-07-01', 3, 3, 3, 7, 482.22, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-09-08', 3, 5, 4, 12, -654.3, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-07-05', 2, 6, 1, 3, -310.4, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-08-05', 2, 4, 5, 14, 336.62, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-09-15', 2, 10, 2, 4, -308.83, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-08-15', 1, 2, 3, 8, -372.51, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-08-23', 1, 9, 3, 8, 659.73, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-09-26', 3, 4, 4, 10, -776.77, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-07-07', 1, 4, 4, 12, -431.5, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-07-14', 1, 3, 2, 5, -536.37, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-05-13', 3, 7, 3, 7, 744.33, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-11-24', 2, 3, 1, 2, -27.79, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-11-20', 1, 9, 5, 15, 19.87, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-12-05', 1, 9, 4, 12, -99.48, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-11-14', 2, 2, 2, 5, 444.92, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-10-21', 1, 5, 1, 3, 446.92, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-05-19', 2, 3, 4, 12, 715.88, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-05-21', 2, 7, 3, 7, -634.13, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-10-22', 2, 6, 5, 13, -330.97, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-10-21', 2, 10, 3, 8, -475.79, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-12-06', 1, 6, 4, 11, 86.24, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-04-10', 3, 3, 3, 8, 438.75, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-12-18', 3, 3, 1, 3, -248.93, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-12-05', 2, 4, 3, 7, 80.63, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-09-28', 1, 6, 2, 6, -384.86, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-07-04', 3, 7, 4, 10, 797.13, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-02-11', 3, 7, 3, 9, 630.4, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-07-20', 3, 2, 5, 13, 376.01, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-09-13', 2, 2, 2, 5, -238.94, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-06-12', 3, 8, 1, 3, 359.51, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-03-01', 3, 8, 5, 15, -132.46, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-02-13', 1, 9, 3, 7, 248.79, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-10-09', 1, 4, 4, 11, -154.51, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-07-25', 2, 6, 3, 9, 585.21, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-05-24', 3, 3, 3, 7, 332.79, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-07-11', 3, 7, 1, 2, 128.14, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-07-05', 2, 1, 4, 12, -791.8, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-01-30', 2, 7, 2, 4, 16.26, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-05-30', 1, 1, 4, 10, -462.19, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-10-18', 2, 6, 1, 2, -582.81, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-02-11', 3, 9, 4, 12, -540.11, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-07-17', 2, 7, 1, 1, -280.0, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-07-23', 2, 5, 4, 12, 524.33, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-04-05', 1, 7, 5, 13, 714.33, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-10-08', 1, 7, 3, 7, -241.1, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-06-12', 1, 1, 4, 11, -553.52, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-03-13', 3, 1, 4, 11, 677.09, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-10-26', 1, 3, 2, 5, 6.19, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-03-30', 1, 1, 1, 3, 79.63, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-06-15', 3, 7, 3, 7, -483.18, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-01-01', 2, 4, 4, 12, -374.12, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-08-16', 3, 4, 1, 2, 624.78, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-09-24', 2, 7, 2, 4, -379.42, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-07-09', 1, 2, 4, 10, 373.28, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-05-16', 2, 10, 3, 7, 470.91, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-09-07', 1, 3, 5, 13, 440.97, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-06-16', 1, 5, 5, 14, -746.86, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-02-10', 1, 10, 2, 5, -37.47, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-03-07', 3, 5, 2, 4, 579.57, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-10-20', 1, 5, 2, 6, 612.92, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-06-06', 2, 3, 4, 12, -376.31, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-09-27', 3, 2, 2, 6, -65.37, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-03-20', 3, 8, 5, 15, 243.85, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-05-16', 3, 2, 1, 3, 386.47, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-04-18', 1, 8, 4, 10, 74.89, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-04-21', 1, 8, 4, 10, -241.79, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-07-10', 2, 6, 1, 1, -202.97, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-12-09', 1, 8, 1, 1, 142.81, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-05-19', 3, 8, 2, 6, -509.77, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-04-15', 1, 6, 4, 12, 344.08, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-06-12', 1, 6, 1, 1, 400.15, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-08-06', 3, 10, 5, 15, 260.49, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-11-25', 1, 5, 4, 12, -673.41, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-01-17', 2, 4, 2, 4, 332.84, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-06-24', 2, 2, 4, 12, 747.67, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-05-21', 2, 4, 4, 12, -703.21, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-07-02', 2, 4, 5, 13, -164.95, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-04-30', 1, 6, 4, 10, 327.3, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-03-11', 2, 8, 5, 13, 609.14, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-01-07', 1, 5, 1, 1, -760.87, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-06-23', 2, 5, 1, 3, -96.68, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-12-29', 2, 9, 4, 12, -687.22, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-01-05', 1, 4, 2, 5, -228.39, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-05-13', 3, 5, 5, 13, 787.22, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-08-07', 2, 7, 1, 2, -736.88, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-07-20', 1, 7, 3, 9, 509.91, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-03-28', 3, 6, 2, 6, 316.74, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-05-04', 2, 6, 1, 1, 673.55, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-01-11', 1, 10, 4, 10, 567.61, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-01-08', 3, 9, 1, 1, 373.79, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-08-26', 1, 1, 5, 14, 250.79, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-01-29', 3, 1, 1, 1, -770.54, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-10-10', 3, 1, 2, 6, -397.23, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-10-25', 3, 10, 1, 2, 397.42, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-08-06', 3, 5, 5, 15, 487.99, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-12-15', 2, 9, 4, 10, 179.6, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-11-30', 2, 8, 4, 12, -782.29, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-04-30', 3, 10, 2, 6, -190.31, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-02-19', 2, 6, 1, 1, -151.45, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-02-14', 2, 7, 3, 7, 90.08, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-07-07', 2, 4, 4, 12, 680.12, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-11-11', 3, 2, 2, 4, 764.12, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-09-14', 2, 2, 4, 12, -773.47, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-05-21', 3, 1, 5, 13, 46.98, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-04-05', 2, 4, 4, 12, -278.12, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-02-03', 3, 5, 3, 9, -630.01, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-01-24', 2, 5, 3, 9, 551.68, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-08-31', 2, 2, 5, 13, 641.31, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-09-13', 1, 1, 5, 15, -176.71, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-07-27', 1, 4, 1, 2, 519.58, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-04-09', 3, 6, 4, 12, 201.06, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-11-25', 1, 6, 3, 7, -17.74, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-05-26', 3, 9, 3, 9, 569.35, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-12-29', 2, 10, 2, 4, 663.92, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-12-19', 2, 1, 1, 1, -475.02, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-10-31', 2, 9, 2, 4, -156.03, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-07-10', 1, 4, 2, 5, 547.26, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-05-24', 1, 6, 5, 13, 16.76, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-12-29', 1, 10, 3, 7, -380.72, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-11-23', 2, 2, 3, 8, 136.55, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-12-15', 3, 7, 3, 9, 104.0, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-12-23', 2, 5, 4, 10, 88.18, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-05-05', 3, 1, 5, 13, 483.43, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-05-09', 1, 10, 3, 7, -66.89, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-03-08', 2, 3, 3, 8, 278.78, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-02-15', 1, 1, 5, 13, 115.14, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-02-25', 3, 10, 3, 9, -312.82, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-04-30', 2, 4, 5, 15, 439.37, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-11-25', 1, 9, 3, 8, -686.18, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-12-06', 1, 8, 1, 2, -559.63, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-10-12', 2, 8, 3, 8, 527.25, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-09-25', 3, 5, 2, 5, 22.39, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-12-12', 3, 3, 2, 6, 524.98, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-03-21', 2, 5, 5, 14, -429.34, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-11-27', 2, 6, 1, 1, 587.04, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-03-26', 2, 8, 4, 12, 164.9, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-11-07', 3, 6, 4, 10, 796.33, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-12-23', 3, 7, 2, 6, -338.2, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-08-25', 2, 7, 3, 8, -103.59, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-02-26', 1, 1, 3, 8, -564.32, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-10-22', 3, 9, 4, 11, 254.77, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-08-26', 2, 9, 2, 5, 611.15, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-10-29', 3, 9, 1, 3, -228.34, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-02-12', 1, 6, 1, 1, -536.62, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-03-20', 2, 7, 1, 3, -704.64, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-01-14', 1, 9, 1, 2, -263.97, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-12-29', 3, 1, 3, 9, 141.42, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-08-26', 1, 9, 4, 10, -664.79, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-08-15', 3, 5, 1, 1, 310.68, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-02-19', 1, 10, 2, 5, -525.07, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-12-28', 3, 4, 4, 12, -560.15, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-04-30', 3, 6, 2, 4, 158.68, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-12-14', 1, 5, 2, 4, -550.73, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-10-31', 3, 6, 2, 4, -519.36, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-01-07', 1, 5, 4, 10, 455.24, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-04-08', 2, 6, 3, 7, -110.87, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-06-07', 3, 4, 5, 13, -478.76, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-10-16', 1, 2, 2, 6, 342.97, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-12-02', 1, 3, 3, 9, -104.08, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-06-23', 1, 6, 2, 6, 510.42, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-11-03', 1, 1, 5, 15, -591.61, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-09-16', 3, 6, 4, 10, -650.25, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-01-09', 3, 5, 2, 6, -116.13, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-03-05', 2, 2, 3, 7, 20.74, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-02-15', 2, 4, 3, 7, -32.12, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-07-29', 3, 4, 1, 2, 312.04, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-01-15', 1, 2, 5, 14, -407.13, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-11-17', 2, 2, 3, 8, 521.29, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-04-08', 2, 4, 4, 12, 574.3, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-10-19', 2, 1, 5, 15, -161.62, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-07-11', 3, 6, 2, 5, 701.52, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-05-03', 1, 6, 4, 12, 105.19, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-09-22', 2, 4, 3, 7, 608.65, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-11-30', 1, 10, 4, 11, -345.76, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-01-18', 3, 1, 5, 15, 650.79, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-01-31', 2, 8, 3, 8, -90.84, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-07-04', 1, 8, 3, 8, -309.93, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-02-15', 2, 1, 5, 13, 357.64, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-09-30', 1, 1, 4, 12, 306.0, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-10-05', 2, 7, 1, 3, -9.54, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-12-06', 2, 10, 3, 9, 321.9, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-04-27', 1, 1, 4, 10, 62.91, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-08-24', 2, 2, 3, 7, 752.5, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-03-31', 2, 1, 5, 15, -360.38, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-06-22', 2, 4, 3, 9, 675.04, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-02-10', 1, 3, 4, 11, -112.44, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-03-28', 3, 3, 1, 3, -256.07, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-10-05', 3, 6, 4, 12, 651.93, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-03-14', 3, 3, 3, 9, -750.92, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-05-30', 2, 4, 3, 9, -744.62, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-04-18', 2, 7, 5, 14, 174.71, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-01-04', 3, 2, 3, 9, 17.48, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-01-18', 3, 10, 5, 14, 251.74, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-07-06', 3, 9, 1, 2, 268.37, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-02-11', 1, 5, 3, 8, 289.43, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-02-04', 3, 3, 2, 6, 788.29, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-06', 3, 6, 2, 5, 434.15, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-03-22', 2, 8, 2, 4, 762.27, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-02-26', 2, 9, 1, 1, 65.86, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-01-20', 3, 8, 3, 7, 304.39, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-09-29', 3, 10, 5, 15, 297.14, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-06-28', 2, 3, 3, 9, 336.66, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-05-08', 2, 9, 1, 1, 383.93, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-06-12', 3, 8, 3, 8, 92.0, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-07-12', 2, 9, 3, 9, -177.87, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-01-17', 3, 8, 4, 12, 724.09, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-08-15', 3, 8, 5, 14, -462.35, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-12-23', 3, 7, 3, 7, 577.15, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-10-31', 3, 1, 3, 8, -585.01, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-12-30', 2, 5, 4, 11, -723.24, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-02-25', 3, 3, 4, 12, -112.91, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-09-26', 1, 5, 5, 13, -107.98, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-11-13', 3, 6, 1, 3, -395.08, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-03-28', 3, 2, 3, 8, 460.43, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-04-21', 2, 1, 4, 12, 750.68, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-02-22', 3, 1, 2, 6, 733.84, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-03-13', 3, 2, 1, 3, 641.27, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-10-10', 3, 1, 1, 1, 206.37, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-01-25', 1, 4, 3, 7, 583.98, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-09-25', 2, 4, 2, 5, -614.88, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-11-28', 1, 6, 1, 1, 67.33, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-08-05', 3, 8, 5, 14, -416.65, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-05-14', 2, 3, 3, 8, -223.25, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-12-07', 2, 7, 1, 3, -535.67, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-02-24', 2, 3, 1, 2, 669.87, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-12-23', 1, 3, 2, 5, 143.54, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-01-22', 2, 7, 5, 15, 351.39, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-05-08', 3, 2, 5, 13, 707.43, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-05-29', 3, 2, 2, 6, -625.74, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-04-08', 3, 9, 1, 1, 652.36, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-04-16', 3, 6, 3, 9, 198.14, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-08-24', 3, 8, 5, 13, -388.04, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-02-12', 3, 5, 3, 7, -681.3, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-05-06', 3, 4, 5, 13, -129.52, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-01-07', 3, 9, 1, 2, -682.26, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-04-12', 2, 2, 4, 10, 626.67, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-10-11', 1, 6, 5, 13, -257.39, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-11-03', 2, 5, 2, 6, 516.68, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-03-12', 1, 3, 1, 3, -304.09, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-01-26', 3, 5, 4, 12, -591.73, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-01-28', 1, 3, 4, 12, -712.34, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-07-15', 3, 7, 5, 13, 240.64, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-03-04', 2, 10, 5, 14, 97.02, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-08-29', 1, 2, 5, 14, 316.4, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-10-14', 2, 7, 3, 7, 628.15, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-11-02', 2, 6, 5, 14, 620.66, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-05-09', 3, 7, 4, 10, 758.69, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-01-02', 3, 1, 3, 7, 779.98, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-01-05', 3, 5, 4, 12, -429.75, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-09-08', 2, 5, 1, 1, -208.39, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-26', 1, 2, 5, 14, 651.41, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-11-04', 2, 2, 5, 13, 711.95, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-06-21', 1, 10, 5, 13, -165.08, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-06-22', 3, 3, 2, 5, -709.76, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-06-29', 2, 7, 2, 6, 259.85, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-07-25', 2, 5, 5, 13, -669.36, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-05-24', 2, 2, 4, 10, 747.91, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-09-29', 3, 5, 3, 8, -710.06, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-01-13', 3, 3, 5, 13, 644.4, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-09-04', 3, 3, 2, 4, 667.56, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-01-25', 1, 3, 3, 7, -787.23, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-02-04', 2, 7, 1, 1, 42.82, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-01-19', 3, 4, 5, 14, -226.15, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-08-01', 2, 3, 3, 7, 422.66, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-04-13', 2, 1, 1, 1, -652.28, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-03-13', 2, 9, 1, 3, -398.77, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-07-26', 1, 5, 5, 15, -546.35, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-12-04', 3, 5, 5, 14, 548.95, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-11-24', 1, 10, 4, 12, 616.57, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-06-14', 1, 3, 3, 7, -370.65, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-04-19', 1, 9, 5, 15, 51.3, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-01-25', 2, 9, 5, 13, 245.18, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-04-09', 3, 10, 1, 2, -453.8, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-12-05', 3, 9, 1, 2, -536.57, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-06-08', 2, 2, 1, 1, 491.06, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-12-31', 1, 9, 1, 1, -590.31, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-10-21', 1, 1, 4, 12, -15.33, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-10-30', 3, 1, 3, 8, 746.37, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-07-20', 3, 8, 3, 9, 409.41, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-12-30', 3, 1, 4, 11, -552.27, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-06-19', 1, 2, 5, 13, 178.79, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-11-02', 2, 3, 4, 12, 277.57, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-03-14', 1, 9, 1, 3, 660.13, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-04-08', 3, 10, 5, 13, -302.84, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-09-23', 2, 10, 5, 14, -268.7, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-07-11', 2, 6, 3, 7, 149.68, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-12-21', 2, 7, 1, 3, 436.18, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-04-15', 3, 4, 2, 6, -144.5, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-08-11', 3, 2, 3, 8, -89.82, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-05-11', 1, 8, 3, 7, -645.54, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-11-03', 1, 4, 5, 13, -242.36, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-08-25', 3, 1, 1, 1, 446.19, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-03-18', 2, 5, 5, 14, 345.39, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-11-28', 2, 1, 1, 1, -450.56, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-07-24', 1, 6, 3, 8, 362.85, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-06-27', 1, 6, 5, 15, -452.29, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-04-25', 2, 6, 5, 14, -250.29, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-05-10', 3, 2, 4, 10, -779.34, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-07-23', 2, 10, 4, 12, -774.54, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-02-02', 3, 1, 2, 6, 693.62, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-04-17', 2, 7, 2, 6, 543.43, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-06-27', 3, 5, 5, 15, -634.54, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-04-06', 3, 8, 1, 3, -331.11, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-06-08', 1, 7, 2, 4, 234.64, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-11-01', 3, 7, 4, 10, 27.67, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-05-06', 2, 4, 5, 15, 117.34, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-09-14', 2, 1, 5, 13, -791.55, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-10-10', 1, 1, 3, 7, -485.87, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-04-03', 1, 6, 4, 11, 188.95, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-11-05', 1, 2, 3, 8, 64.8, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-10-04', 3, 5, 5, 15, 230.12, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-01-27', 1, 2, 5, 14, 680.2, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-06-08', 1, 5, 1, 2, -755.07, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-01-22', 3, 6, 4, 11, -699.74, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-04-09', 3, 10, 4, 12, -762.29, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-03-13', 3, 7, 2, 4, -549.23, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-09-11', 2, 4, 5, 13, 123.4, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-09-28', 1, 4, 4, 11, -21.69, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-03-26', 3, 3, 1, 1, -101.95, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-01-29', 3, 8, 1, 2, -263.01, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-11-03', 1, 1, 1, 1, 375.17, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-12-10', 1, 8, 1, 2, 713.77, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-08-08', 1, 5, 2, 5, -209.8, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-06-16', 1, 1, 5, 13, 611.79, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-03-06', 3, 8, 1, 2, -641.61, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-06-26', 2, 4, 4, 11, -720.25, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-02-13', 1, 6, 3, 8, -497.97, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-04-12', 1, 9, 3, 8, -407.26, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-12-29', 3, 4, 4, 11, 11.53, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-04-25', 3, 1, 1, 2, 465.49, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-09-22', 2, 7, 3, 8, -78.56, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-09-14', 3, 7, 2, 5, 573.36, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-11-14', 2, 6, 3, 9, 320.51, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-12-11', 2, 2, 5, 15, -27.92, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-05-23', 3, 3, 1, 1, -483.85, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-04-05', 1, 9, 4, 10, 643.19, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-03-13', 1, 3, 2, 5, -15.92, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-05-22', 2, 2, 1, 1, -401.46, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-04-25', 2, 2, 1, 2, -299.57, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-03-03', 3, 6, 1, 3, 154.98, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-01-23', 2, 2, 5, 15, -224.21, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-06-02', 3, 8, 5, 15, -665.95, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-04-30', 1, 7, 3, 7, 244.73, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-06-08', 2, 2, 5, 15, 27.33, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-05-12', 1, 1, 1, 3, -545.04, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-01-14', 2, 1, 2, 5, -592.05, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-12-20', 1, 9, 4, 11, 709.19, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-03-17', 1, 8, 4, 11, 180.39, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-04-22', 3, 6, 2, 6, 715.22, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-08-27', 1, 2, 1, 1, 443.32, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-10-28', 2, 5, 3, 7, 139.35, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-02-27', 1, 1, 2, 5, -494.77, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-12-22', 3, 5, 3, 9, 400.17, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-10-26', 1, 6, 5, 15, 289.79, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-02-05', 2, 4, 4, 11, 285.52, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-07-02', 3, 1, 3, 7, 613.1, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-03-14', 1, 4, 4, 12, 498.84, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-04-29', 2, 3, 3, 9, -437.31, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-06-14', 1, 6, 1, 3, -263.34, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-12-03', 2, 8, 1, 1, 417.29, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-09-03', 3, 10, 2, 4, 237.6, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-03-20', 2, 10, 5, 13, 119.04, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-02-15', 3, 7, 2, 5, 178.78, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-10-05', 1, 10, 1, 3, 188.36, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-06-27', 2, 1, 4, 12, 162.22, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-01-24', 2, 8, 5, 14, -257.54, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-07-03', 2, 9, 4, 10, 675.44, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-09-20', 2, 2, 4, 10, -473.25, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-06-08', 1, 8, 4, 10, 196.37, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-04-12', 1, 8, 2, 5, -357.46, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-11-28', 1, 8, 5, 15, 441.7, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-07-20', 3, 10, 4, 12, 249.36, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-01-12', 1, 2, 1, 2, -148.31, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-03-28', 2, 7, 5, 13, 79.64, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-12-11', 1, 8, 2, 4, -88.11, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-10-14', 3, 7, 1, 3, 489.6, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-11-17', 2, 1, 3, 7, 49.08, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-08-14', 2, 4, 2, 4, -43.25, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-12-08', 1, 5, 3, 9, -386.12, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-03-09', 3, 2, 1, 3, 243.97, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-11-01', 2, 1, 3, 9, 340.44, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-07-08', 1, 2, 3, 7, -495.32, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-11-15', 3, 9, 3, 9, 588.4, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-01-02', 2, 8, 1, 2, -462.49, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-12-11', 1, 6, 4, 12, -614.43, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-03-16', 2, 1, 3, 7, -596.64, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-02-02', 2, 7, 2, 5, 627.14, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-10-31', 1, 4, 5, 15, 646.85, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-12-31', 3, 4, 1, 2, -798.52, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-01-21', 2, 6, 1, 3, -664.85, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-07-15', 1, 4, 2, 5, -217.92, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-04-27', 1, 2, 5, 15, 511.04, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-11-13', 2, 2, 3, 9, 353.98, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-08-15', 2, 7, 4, 10, -239.82, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-07-16', 2, 5, 2, 5, -383.8, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-01-10', 1, 1, 2, 6, -780.53, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-02-26', 2, 7, 1, 1, 590.76, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-02-01', 1, 2, 1, 3, -25.22, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-01-29', 3, 5, 4, 12, -196.35, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-08-23', 1, 10, 1, 2, 463.19, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-08-11', 3, 5, 1, 1, 544.6, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-10-26', 2, 4, 1, 2, -799.9, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-10-11', 1, 3, 5, 13, 317.08, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-11-06', 1, 5, 2, 4, -714.2, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-09-01', 3, 2, 1, 3, -749.99, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-01-02', 3, 8, 5, 15, 691.52, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-07-08', 1, 6, 4, 12, -63.36, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-04-27', 1, 7, 2, 6, 322.2, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-03-24', 3, 2, 1, 3, 155.16, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-06-22', 3, 5, 2, 6, -732.93, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-08-16', 3, 4, 1, 2, 492.33, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-11-26', 2, 4, 1, 2, 85.31, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-01-24', 3, 8, 2, 4, 40.93, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-04-27', 3, 8, 2, 5, 161.35, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-11-01', 1, 1, 5, 15, -623.67, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-03-25', 1, 8, 3, 9, 716.61, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-04-19', 2, 8, 4, 10, -655.99, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-01-23', 2, 9, 4, 10, -591.3, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-07-06', 1, 7, 1, 3, 31.9, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-10-14', 2, 6, 4, 10, 360.18, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-10-17', 1, 5, 2, 4, 785.02, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-10-18', 1, 7, 3, 7, 506.12, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-03-11', 2, 1, 1, 3, 700.64, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-09-14', 3, 9, 5, 13, -299.98, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-06-07', 2, 8, 5, 15, 11.0, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-07-11', 1, 7, 2, 6, -783.72, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-11-24', 1, 3, 5, 15, 526.79, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-04-22', 2, 10, 2, 6, 592.19, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-09-23', 1, 10, 4, 12, -399.11, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-01-25', 3, 5, 3, 7, -201.42, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-02-12', 3, 1, 1, 2, 542.75, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-11-09', 3, 8, 4, 11, 670.74, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-02-04', 1, 9, 3, 7, 409.84, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-02-24', 1, 9, 2, 4, -455.63, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-03-19', 3, 6, 2, 5, -732.75, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-05-20', 2, 6, 2, 4, -209.99, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-03-13', 2, 6, 2, 6, 342.93, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-05-26', 3, 2, 5, 15, -762.96, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-11-02', 1, 8, 5, 15, 466.91, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-06-21', 2, 2, 4, 11, -550.52, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-02-20', 2, 1, 3, 8, -451.76, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-02-16', 1, 9, 4, 11, -768.57, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-22', 1, 7, 5, 13, -620.23, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-02-08', 2, 9, 2, 5, 513.71, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-04-05', 3, 10, 1, 1, -547.6, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-02-07', 3, 10, 1, 1, 34.63, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-11-30', 3, 8, 1, 1, 785.78, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-12-30', 1, 10, 1, 3, -118.24, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-10-21', 2, 7, 4, 12, 263.11, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-06-10', 3, 5, 5, 15, -438.65, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-10-26', 1, 5, 3, 7, 484.38, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-10-01', 1, 10, 2, 4, -304.98, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-01-17', 2, 7, 1, 1, -665.23, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-10-13', 2, 5, 2, 5, 696.38, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-09-22', 3, 3, 3, 7, 171.6, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-09-16', 1, 1, 2, 4, -558.22, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-09-13', 3, 10, 2, 4, -579.98, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-01-05', 2, 6, 1, 2, 625.31, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-08-13', 2, 5, 4, 12, -492.84, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-10-28', 1, 7, 5, 13, -148.16, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-05-22', 3, 7, 2, 6, -744.58, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-06-16', 3, 8, 1, 2, -655.0, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-04-04', 2, 9, 5, 15, -308.52, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-02-25', 3, 9, 4, 11, 760.5, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-04-29', 1, 4, 1, 1, -784.56, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-01-09', 2, 10, 3, 7, 496.33, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-09-02', 2, 8, 4, 11, 780.58, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-12-30', 2, 8, 4, 10, 130.16, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-05-03', 1, 3, 1, 3, -725.2, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-03-16', 1, 5, 3, 9, 248.14, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-11-24', 1, 3, 4, 10, -71.85, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-03-16', 3, 10, 2, 6, 134.57, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-12-17', 1, 8, 5, 15, 41.12, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-02-12', 2, 1, 4, 10, 790.3, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-18', 3, 1, 4, 11, -175.84, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-08-04', 3, 1, 1, 1, -358.87, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-03-14', 1, 2, 3, 7, 127.95, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-08-28', 2, 10, 1, 3, 601.56, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-11-17', 1, 5, 2, 4, -767.75, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-11-26', 1, 7, 5, 14, 196.99, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-12-16', 2, 2, 1, 2, -406.25, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-04-04', 1, 3, 5, 15, 573.46, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-03-21', 2, 9, 5, 13, -728.14, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-04-24', 1, 10, 2, 6, -365.04, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-05-17', 2, 8, 1, 2, -288.57, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-10-05', 3, 7, 1, 2, 640.99, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-01-30', 3, 3, 5, 13, -598.8, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-04-12', 2, 4, 2, 4, 779.36, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-12-03', 3, 7, 4, 11, -529.11, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-10-10', 2, 3, 4, 12, -239.44, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-10-01', 3, 10, 3, 7, -547.39, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-10-10', 2, 7, 4, 12, -151.39, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-09-06', 1, 2, 5, 13, 45.48, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-09-14', 1, 3, 1, 2, 484.86, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-07-12', 3, 4, 5, 15, -580.34, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-12-27', 1, 3, 2, 5, 536.9, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-03-21', 2, 1, 5, 15, 206.37, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-12-15', 2, 6, 1, 3, -136.81, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-06-20', 3, 8, 2, 6, 24.83, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-11-05', 1, 8, 4, 10, 168.8, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-06-30', 2, 2, 2, 6, -377.03, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-01-29', 3, 3, 3, 7, -134.36, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-05-23', 3, 7, 2, 4, 9.24, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-12-02', 1, 5, 4, 10, 345.75, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-04-07', 1, 3, 3, 9, 496.94, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-03-25', 3, 4, 3, 9, -333.95, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-05-14', 1, 1, 2, 4, 477.4, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-10-22', 3, 4, 3, 8, -629.91, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-07-19', 3, 4, 5, 15, -80.6, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-02-27', 2, 4, 2, 4, 258.71, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-02-08', 3, 8, 5, 15, -5.16, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-05-13', 1, 3, 5, 15, 233.97, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-09-08', 2, 10, 4, 11, 794.97, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-09-28', 3, 9, 1, 3, 150.02, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-11-25', 1, 3, 3, 9, 115.68, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-10-02', 2, 8, 3, 7, -783.83, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-02-27', 2, 2, 4, 11, 579.06, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-12-19', 3, 6, 4, 11, -244.82, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-11-27', 3, 10, 2, 5, -580.99, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-06-10', 1, 5, 3, 8, -253.94, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-02-13', 3, 7, 3, 7, -787.36, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-07-27', 1, 1, 5, 13, 584.31, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-04-26', 2, 5, 2, 4, 342.04, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-07-10', 1, 1, 3, 7, 485.77, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-07-30', 2, 10, 1, 1, 733.63, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-09-29', 3, 3, 2, 4, -451.09, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-10-19', 1, 10, 4, 12, 450.18, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-03-04', 3, 1, 4, 12, 69.72, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-08-13', 2, 8, 1, 1, -41.27, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-04-08', 3, 7, 3, 7, -8.01, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-12-06', 1, 3, 2, 5, 111.58, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-05-20', 1, 5, 5, 13, -526.43, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-03-04', 2, 1, 3, 7, -435.53, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-12-18', 1, 2, 2, 5, -546.62, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-02-29', 3, 3, 1, 1, -277.55, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-01-30', 2, 3, 2, 4, 100.0, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-11-10', 3, 1, 3, 7, -464.63, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-06-01', 2, 2, 1, 2, -609.07, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-01-09', 1, 9, 2, 4, 14.77, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-11-13', 2, 8, 2, 5, -363.75, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-09-06', 1, 1, 2, 6, 327.11, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-06-26', 1, 6, 3, 8, -674.97, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-06-29', 1, 6, 1, 1, 197.64, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-11-16', 1, 7, 3, 9, -657.76, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-08-02', 3, 4, 5, 13, 245.22, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-08-05', 3, 10, 3, 7, -121.87, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-04-10', 3, 5, 5, 13, -20.76, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-02-19', 2, 3, 4, 11, -404.0, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-10-18', 2, 6, 2, 6, 452.22, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-07-03', 3, 6, 3, 7, 670.61, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-07-25', 2, 5, 2, 4, 12.25, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-05-23', 1, 7, 2, 6, -463.69, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-09-18', 2, 2, 1, 1, 332.59, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-03-01', 1, 8, 3, 9, 528.26, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-02-28', 1, 1, 4, 11, -747.5, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-04-26', 2, 4, 5, 15, -264.28, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-07-05', 1, 3, 2, 5, 376.81, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-01-12', 3, 8, 4, 12, -128.47, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-05-19', 3, 10, 2, 6, -488.07, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-06-26', 2, 10, 2, 5, 132.21, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-06-24', 3, 1, 2, 6, 152.57, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-11-16', 2, 5, 2, 6, 681.26, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-12-19', 1, 9, 4, 10, -389.93, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-03-02', 2, 9, 2, 6, -454.17, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-07-30', 3, 2, 2, 4, 12.29, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-12-20', 3, 4, 1, 1, 19.62, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-06-11', 1, 10, 4, 12, 245.6, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-03-11', 2, 1, 4, 12, 758.31, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-06-16', 1, 7, 1, 3, -397.06, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-09-02', 3, 4, 4, 12, 696.43, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-12-14', 2, 6, 3, 8, -718.28, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-11-01', 3, 8, 5, 15, -148.89, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-04-08', 1, 7, 2, 4, -681.29, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-07-20', 1, 6, 3, 7, -677.49, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-03-14', 2, 3, 4, 10, 303.17, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-12-01', 2, 1, 2, 6, 130.32, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-03-28', 1, 4, 2, 5, 587.28, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-03-18', 3, 10, 1, 1, -81.78, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-02-22', 1, 1, 5, 14, -797.24, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-11-14', 3, 7, 5, 15, -61.02, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-01-25', 1, 8, 2, 5, -256.02, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-04-24', 2, 5, 5, 15, 681.58, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-01-01', 1, 4, 5, 13, 678.16, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-07-08', 2, 10, 4, 12, 618.14, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-09-14', 3, 7, 1, 1, 529.66, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-09-10', 1, 4, 5, 13, -111.44, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-05-14', 3, 7, 1, 3, 92.95, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-06-01', 2, 4, 4, 10, 220.11, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-05-25', 1, 8, 5, 14, -100.48, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-07-03', 2, 6, 1, 2, 173.96, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-04-28', 3, 2, 3, 8, -554.04, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-03-07', 1, 3, 5, 13, -261.1, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-06-05', 2, 1, 3, 8, -163.13, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-05-23', 2, 7, 2, 5, 672.8, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-01-01', 2, 2, 1, 3, -516.34, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-12-01', 2, 7, 5, 15, -715.97, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-10-26', 3, 7, 1, 2, 55.28, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-04-28', 1, 1, 1, 1, 252.87, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-07-22', 2, 9, 2, 6, 253.76, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-08-12', 2, 3, 3, 9, 575.47, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-07-01', 1, 1, 3, 7, -87.83, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-06-10', 2, 1, 5, 13, -335.12, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-04-26', 1, 6, 4, 11, 204.8, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-01-26', 1, 7, 4, 12, 459.18, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-12-09', 3, 7, 4, 12, 655.26, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-01-20', 2, 6, 3, 9, -611.28, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-04-06', 2, 6, 2, 5, 736.02, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-06-17', 3, 4, 4, 10, 270.64, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-01-21', 1, 10, 5, 15, -661.68, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-10-19', 3, 9, 3, 9, 429.91, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-07-28', 3, 10, 5, 14, -223.68, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-08-23', 3, 3, 4, 10, 297.5, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-04-22', 2, 2, 3, 7, -350.54, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-10-01', 2, 2, 2, 4, -295.48, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-05-09', 1, 3, 1, 1, 694.54, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-03-25', 2, 2, 5, 15, 120.55, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-05-08', 2, 10, 5, 14, -788.12, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-03-06', 2, 1, 5, 13, -77.81, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-09-20', 1, 2, 3, 8, -589.74, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-03-06', 2, 10, 2, 5, -474.79, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-09-09', 1, 1, 4, 12, -258.64, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-10-01', 3, 3, 1, 1, -796.14, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-01-27', 3, 1, 4, 11, 282.87, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-07-13', 1, 1, 2, 5, -265.29, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-12-23', 2, 5, 4, 12, 568.06, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-11-22', 3, 7, 2, 4, 399.03, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-10-17', 2, 4, 1, 3, -50.72, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-09-28', 2, 6, 4, 11, 423.21, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-03-01', 1, 4, 5, 13, 316.73, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-12-08', 2, 7, 1, 2, -261.15, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-11-05', 2, 4, 1, 2, 641.18, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-07-22', 1, 2, 1, 1, -24.3, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-10-03', 3, 5, 1, 1, 57.99, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-02-11', 3, 7, 3, 9, -279.21, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-02-10', 1, 1, 1, 3, 517.05, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-12-07', 2, 3, 3, 9, 693.64, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-03-09', 1, 7, 1, 2, 553.44, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-03-22', 1, 2, 3, 8, -795.62, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-05-05', 3, 10, 2, 6, -715.08, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-01-14', 3, 2, 1, 1, -149.74, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-11-25', 3, 4, 4, 10, -217.12, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-01-10', 1, 7, 3, 8, -723.97, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-07-25', 1, 5, 5, 14, -41.95, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-02-06', 1, 10, 3, 8, 672.06, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-03-04', 1, 7, 5, 14, 641.36, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-06-23', 1, 6, 1, 1, -196.18, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-01-16', 2, 4, 2, 4, 388.74, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-09-07', 2, 8, 3, 9, 790.51, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-08-21', 2, 10, 2, 5, 480.86, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-07-08', 2, 5, 5, 15, -291.35, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-07-14', 3, 10, 5, 13, -292.5, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-02-16', 1, 4, 5, 13, 155.27, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-05-17', 1, 8, 1, 1, -719.33, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-05-14', 2, 1, 1, 1, 570.4, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-09-16', 2, 1, 1, 1, -96.79, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-06-18', 3, 1, 4, 11, 161.63, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-08-13', 1, 4, 1, 3, -712.73, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-05-22', 1, 3, 1, 2, 132.9, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-04-18', 2, 3, 4, 10, 56.37, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-07-05', 1, 2, 2, 5, 141.68, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-11-14', 2, 7, 3, 9, -570.56, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-01-13', 1, 4, 2, 5, -751.08, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-05-11', 2, 8, 4, 10, -163.82, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-06-22', 1, 10, 5, 13, -599.63, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-06-08', 2, 10, 1, 1, -522.01, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-03-27', 2, 9, 1, 2, 270.02, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-01-01', 1, 5, 1, 2, -74.39, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-09-03', 3, 9, 1, 2, 194.35, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-09-08', 3, 1, 3, 7, 189.41, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-11-19', 1, 6, 5, 15, 68.6, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-12-04', 3, 10, 1, 1, -65.87, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-01-07', 2, 4, 5, 15, 649.47, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-11-17', 3, 5, 3, 7, -570.61, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-08-15', 1, 7, 1, 3, -546.2, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-09-21', 3, 2, 1, 1, 423.52, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-10-14', 1, 8, 2, 5, 84.57, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-12-14', 3, 1, 1, 2, -276.28, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-08-04', 1, 2, 1, 1, 270.51, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-04-06', 2, 1, 5, 14, -364.93, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-03-07', 2, 2, 3, 9, -711.31, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-04-17', 2, 1, 3, 9, -503.07, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-01-27', 2, 10, 1, 2, 463.77, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-09-06', 3, 3, 1, 1, 417.44, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-09-13', 3, 2, 4, 10, -332.58, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-11-01', 2, 1, 3, 9, 55.38, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-03-25', 3, 10, 4, 11, 334.28, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-23', 3, 9, 5, 15, 44.9, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-10-04', 2, 1, 4, 10, -325.53, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-10-19', 3, 7, 2, 4, -23.71, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-11-10', 1, 1, 5, 15, -292.87, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-06-11', 1, 5, 5, 15, -553.46, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-10-05', 3, 9, 1, 1, -144.9, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-05-12', 1, 9, 3, 8, -354.85, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-06-03', 1, 3, 3, 7, 272.62, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-09-18', 3, 6, 5, 15, -517.22, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-07-28', 3, 5, 4, 11, -373.59, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-01-09', 2, 2, 4, 12, 448.2, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-10-06', 1, 6, 4, 10, 540.83, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-06-07', 1, 7, 4, 12, -55.99, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-01-26', 2, 7, 4, 10, 233.78, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-10-16', 1, 5, 2, 6, 493.12, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-12-10', 3, 5, 3, 9, -611.95, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-12-03', 1, 5, 5, 14, -205.14, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-04-14', 3, 1, 3, 9, -606.54, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-08-10', 2, 7, 2, 5, 628.18, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-06-25', 2, 2, 4, 12, -202.03, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-10-24', 1, 7, 5, 15, -521.98, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-05-24', 1, 5, 3, 9, 713.53, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-09-30', 1, 7, 3, 8, 352.36, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-01-28', 2, 4, 1, 3, 218.74, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-11-02', 2, 6, 3, 7, 520.85, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-03-13', 1, 2, 3, 9, 220.25, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-01-18', 2, 7, 4, 12, 122.26, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-09-05', 2, 4, 1, 2, 738.27, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-02-12', 3, 9, 5, 15, -64.85, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-01-22', 2, 3, 2, 4, 182.2, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-03-09', 1, 10, 2, 5, -283.65, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-10-13', 1, 10, 3, 8, 303.99, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-12-12', 2, 6, 2, 5, -145.49, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-12-02', 1, 4, 1, 2, 17.91, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-09-25', 3, 9, 2, 6, -132.4, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-01-28', 1, 4, 5, 15, 238.29, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-08-16', 2, 2, 4, 12, 268.13, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-05-09', 3, 9, 4, 12, 522.93, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-10-16', 2, 4, 5, 15, -50.91, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-06-14', 2, 1, 2, 4, -370.26, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-10-21', 3, 3, 1, 2, 276.3, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-08-09', 2, 7, 4, 10, -556.06, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-09-28', 3, 3, 4, 12, 106.06, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-11-03', 1, 6, 1, 3, -578.99, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-03-22', 3, 6, 4, 11, 420.55, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-03-17', 3, 5, 5, 14, 634.76, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-12-03', 3, 10, 3, 7, -336.28, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-05-22', 2, 7, 2, 4, -94.28, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-04-29', 3, 10, 3, 8, 289.74, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-08-07', 1, 6, 3, 8, -573.11, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-12-13', 3, 1, 4, 12, -165.72, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-11-17', 2, 10, 4, 11, 798.7, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-04-11', 1, 4, 4, 11, 439.82, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-03-25', 2, 7, 5, 13, 352.19, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-04-27', 2, 7, 2, 6, 284.22, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-11-28', 2, 9, 4, 10, -747.97, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-12-14', 1, 7, 2, 6, 628.19, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-11-20', 2, 9, 2, 5, -551.15, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-07-27', 3, 9, 1, 1, -31.11, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-05-06', 2, 6, 2, 4, -57.8, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-07-20', 3, 7, 2, 4, 26.57, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-03-03', 1, 4, 1, 1, -293.94, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-09-01', 2, 9, 4, 11, 650.91, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-07-29', 2, 9, 1, 1, 95.5, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-12-03', 1, 1, 3, 7, 203.46, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-04-13', 3, 3, 2, 5, -453.21, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-11-18', 3, 10, 2, 4, 302.6, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-05-04', 1, 10, 3, 9, 754.29, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-10-26', 1, 10, 5, 14, 521.79, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-02-24', 2, 8, 3, 9, -680.19, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-12-22', 2, 1, 3, 7, 367.51, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-06-24', 1, 6, 4, 10, -37.94, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-09-01', 1, 2, 1, 3, -250.74, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-07-27', 1, 9, 3, 9, 596.5, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-10-31', 2, 10, 4, 12, -41.88, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-07-26', 3, 1, 2, 4, 267.87, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-06-12', 3, 4, 5, 14, -465.78, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-04-22', 3, 2, 4, 12, 465.47, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-01-10', 3, 3, 1, 1, 332.9, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-12-06', 1, 1, 5, 13, 253.88, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-12-11', 2, 6, 1, 3, -386.5, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-04-20', 3, 5, 2, 4, 598.2, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-08-16', 3, 4, 1, 2, 387.05, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-11-09', 3, 4, 5, 13, 79.43, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-11-21', 1, 6, 4, 12, -5.09, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-05-17', 1, 3, 1, 2, 539.06, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-05-18', 3, 9, 1, 1, -694.12, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-12-24', 1, 4, 5, 14, -16.36, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-08-20', 2, 2, 1, 3, -330.4, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-04-23', 2, 7, 4, 11, 33.72, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-08-26', 3, 7, 5, 15, 311.34, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-08-11', 2, 8, 4, 10, 278.8, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-07-18', 3, 5, 2, 4, 80.33, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-30', 1, 7, 3, 7, 42.23, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-11-29', 2, 3, 3, 7, -180.67, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-08-05', 2, 3, 3, 8, -509.79, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-10-31', 3, 9, 2, 4, -69.71, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-04-05', 3, 6, 3, 9, 107.57, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-03-24', 3, 10, 5, 13, -28.05, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-06-08', 2, 6, 4, 10, 519.55, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-02-23', 3, 3, 2, 5, 263.29, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-03-30', 2, 10, 5, 14, 560.81, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-12-17', 2, 7, 2, 4, -35.22, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-12-28', 1, 7, 5, 15, 120.98, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-09-25', 2, 9, 4, 12, 700.84, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-02-28', 1, 6, 4, 11, 117.75, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-11-05', 3, 3, 1, 1, -395.83, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-07-05', 1, 6, 1, 3, -706.9, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-12-22', 1, 8, 3, 7, 795.04, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-06-24', 2, 5, 5, 13, -97.14, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-11-17', 2, 9, 5, 15, 469.48, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-05-02', 3, 5, 4, 12, 564.0, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-07-02', 1, 3, 4, 10, -559.32, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-06-29', 3, 6, 4, 12, -473.99, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-02-28', 3, 9, 2, 5, 525.51, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-09-21', 1, 10, 3, 9, 6.38, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-12-19', 2, 7, 4, 11, -243.37, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-12-15', 1, 4, 1, 1, 343.05, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-05-12', 1, 10, 4, 10, 181.64, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-05-29', 1, 2, 1, 2, -598.85, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-11-25', 3, 8, 5, 15, -547.42, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-05-25', 3, 3, 1, 1, -378.12, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-06-12', 3, 2, 5, 14, 59.11, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-01-04', 3, 4, 5, 15, 95.84, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-11-01', 2, 9, 1, 1, 151.16, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-08-17', 1, 6, 4, 12, 51.69, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-11-28', 1, 5, 2, 4, -487.27, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-07-07', 2, 4, 2, 6, -350.22, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-11-23', 2, 4, 1, 2, 581.16, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-12-05', 1, 5, 3, 7, -63.3, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-10-01', 3, 8, 3, 9, -501.28, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-02-15', 2, 10, 3, 7, -669.45, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-05-04', 2, 1, 3, 7, 618.49, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-09-28', 3, 9, 3, 9, 89.05, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-03-10', 2, 9, 1, 2, 298.57, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-01-30', 3, 6, 3, 9, 536.24, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-04-26', 3, 8, 3, 8, 455.57, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-02-22', 3, 5, 5, 13, -46.6, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-05-13', 3, 3, 3, 9, 448.34, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-01-26', 2, 3, 4, 10, -216.13, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-10-24', 1, 9, 5, 14, 272.02, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-10-15', 1, 2, 4, 12, -463.2, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-07-22', 1, 10, 4, 12, 350.37, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-05-29', 1, 3, 4, 10, -718.71, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-02-18', 2, 6, 1, 3, 92.03, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-05-09', 3, 3, 1, 3, 209.33, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-10-13', 3, 6, 3, 7, 656.35, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-08-22', 2, 1, 1, 2, -103.03, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-06-18', 2, 8, 1, 2, 16.85, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-11-07', 2, 2, 4, 12, 787.26, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-02-12', 2, 2, 2, 6, 28.99, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-04-22', 1, 6, 5, 13, 242.85, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-05-10', 3, 1, 5, 15, 568.56, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-05-16', 2, 1, 5, 15, -737.28, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-12-05', 3, 3, 4, 12, 538.99, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-11-14', 2, 1, 2, 4, -501.97, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-02-25', 3, 9, 1, 1, -70.66, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-05-01', 2, 2, 3, 9, 55.56, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-05-21', 3, 7, 5, 15, -164.97, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-11-29', 1, 5, 1, 2, 425.0, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-12-22', 1, 4, 1, 3, -570.87, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-09-15', 3, 2, 3, 7, 169.81, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-11-28', 2, 3, 4, 12, -700.72, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-03-21', 1, 7, 5, 15, -317.06, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-03-27', 3, 9, 5, 15, 648.44, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-09-19', 3, 10, 4, 12, 726.62, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-01-21', 2, 5, 1, 1, 88.19, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-01-03', 2, 8, 2, 6, -356.96, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-09-16', 1, 5, 3, 8, -500.34, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-04-07', 2, 3, 3, 8, 761.76, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-06-26', 3, 8, 1, 1, 636.42, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-06-15', 1, 1, 1, 1, 742.41, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-11-05', 3, 1, 2, 6, 50.06, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-02-15', 1, 2, 2, 4, 510.79, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-03-13', 3, 7, 1, 1, -389.75, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-04-26', 1, 8, 1, 3, -573.62, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-11-10', 2, 3, 2, 6, -294.3, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-12-02', 3, 2, 5, 15, 240.33, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-12-19', 1, 6, 1, 1, -361.4, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-11-02', 2, 9, 3, 9, 368.76, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-01-22', 3, 9, 3, 9, -168.75, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-03-24', 1, 8, 4, 11, -337.58, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-06-27', 2, 3, 1, 2, -515.05, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-04-02', 3, 3, 5, 13, -112.59, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-03-21', 2, 2, 4, 12, 702.81, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-09-11', 3, 8, 1, 3, -125.74, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-02-22', 2, 3, 4, 10, -485.13, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-09-25', 2, 3, 3, 7, 790.42, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-05-22', 2, 9, 1, 1, -780.15, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-03-05', 2, 2, 4, 10, -6.64, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-04-09', 2, 5, 2, 6, 788.44, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-11-22', 3, 5, 1, 1, -160.66, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-01-13', 3, 7, 3, 9, 754.58, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-11-30', 1, 1, 2, 5, -667.37, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-10-22', 1, 3, 2, 4, -604.55, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-07-10', 3, 7, 1, 1, 260.75, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-12-21', 1, 9, 1, 1, -422.88, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-11-17', 2, 5, 5, 13, 473.52, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-01-06', 1, 4, 4, 10, 740.61, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-04-19', 1, 1, 4, 12, 290.55, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-04-28', 3, 1, 3, 7, -305.99, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-07-18', 1, 9, 3, 7, -324.74, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-01-11', 2, 2, 3, 9, 180.7, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-05-14', 1, 7, 2, 5, 740.01, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-07-03', 3, 8, 5, 15, -127.04, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-05-19', 1, 6, 3, 8, 689.24, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-11-25', 3, 5, 4, 12, 731.99, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-01-27', 1, 9, 4, 12, -394.65, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-12-06', 3, 1, 4, 10, -227.14, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-03-28', 3, 4, 1, 1, -776.53, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-10-05', 3, 1, 1, 2, -247.66, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-02-08', 2, 10, 1, 3, 204.19, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-07-13', 3, 2, 5, 14, -329.17, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2023-10-06', 1, 9, 4, 12, 528.75, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-12-20', 2, 7, 2, 6, -101.75, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-10-11', 1, 2, 3, 9, -767.18, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-04-11', 3, 6, 3, 7, -222.26, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-06-19', 1, 4, 3, 9, 490.02, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-03-11', 1, 9, 4, 12, 766.95, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-05-23', 1, 2, 2, 5, 45.11, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-09-14', 2, 6, 2, 5, -503.85, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-09-21', 2, 1, 5, 14, 70.08, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-05-25', 2, 6, 1, 3, -652.59, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-02-21', 2, 6, 2, 4, 717.17, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-09-18', 3, 10, 5, 15, 395.11, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-06-16', 3, 10, 2, 6, -784.12, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-05-16', 3, 10, 5, 13, 98.03, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2021-10-11', 2, 4, 2, 5, 118.07, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2016-03-10', 3, 7, 1, 2, 381.15, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2018-04-20', 1, 8, 1, 3, 40.43, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-10-31', 1, 10, 4, 11, -618.51, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2015-05-21', 3, 2, 1, 1, -367.71, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2019-03-25', 2, 9, 3, 7, -400.63, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-12-28', 2, 2, 3, 7, 321.39, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-09-19', 3, 2, 5, 15, -33.54, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2020-09-25', 1, 5, 1, 2, -6.43, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2024-04-15', 3, 10, 4, 10, 288.25, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2022-07-22', 1, 7, 4, 10, 257.6, 'C');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2025-09-05', 1, 1, 2, 6, -699.57, 'D');
INSERT INTO Mouvement 
    (dateMouvement, idCompte, idTiers, idCategorie, idSousCategorie, montant, typeMouvement)
VALUES 
    ('2017-10-25', 1, 4, 3, 8, 169.08, 'C');
