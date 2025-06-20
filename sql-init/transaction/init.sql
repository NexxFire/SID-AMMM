create table if not exists Categories
(
    idCategorie       int auto_increment
        primary key,
    nomCategorie      varchar(50)                           not null,
    dateHeureCreation timestamp default current_timestamp() null,
    dateHeureMAJ      timestamp default current_timestamp() not null
);

create table if not exists SousCategories
(
    idSousCategorie   int auto_increment
        primary key,
    nomSousCategorie  varchar(50)                           not null,
    idCategorie       int                                   not null,
    dateHeureCreation timestamp default current_timestamp() not null,
    dateHeureMAJ      timestamp default current_timestamp() not null,
    constraint SousCategorie_Categorie_idCategorie_fk
        foreign key (idCategorie) references Categories (idCategorie)
            on delete cascade
);

create table if not exists Utilisateurs
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

create table if not exists Comptes
(
    idCompte          int auto_increment
        primary key,
    descriptionCompte varchar(50)                           not null,
    nomBanque         varchar(50)                           not null,
    idUtilisateur     int                                   not null,
    dateHeureCreation timestamp default current_timestamp() not null,
    dateHeureMAJ      timestamp default current_timestamp() null,
    constraint Compte_Utilisateur_idUtilisateur_fk
        foreign key (idUtilisateur) references Utilisateurs (idUtilisateur)
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
        foreign key (idUtilisateur) references Utilisateurs (idUtilisateur)
);

create table if not exists Virements
(
    idVirement        int auto_increment
        primary key,
    idCompteDebit     int                                       not null,
    idCompteCredit    int                                       not null,
    montant           decimal(6, 2) default 0.00                not null,
    dateVirement      date          default curdate()           not null,
    dateHeureCreation timestamp     default current_timestamp() not null,
    dateHeureMAJ      timestamp     default current_timestamp() not null,
    idCategorie       int                                       null,
    constraint Virement_Compte_idCompte_fk
        foreign key (idCompteDebit) references Comptes (idCompte),
    constraint Virement_Compte_idCompte_fk_2
        foreign key (idCompteCredit) references Comptes (idCompte)
);

create table if not exists Mouvements
(
    idMouvement       int auto_increment
        primary key,
    dateMouvement     date      default curdate()           not null,
    idCompte          int                                   not null,
    idTiers           int                                   null,
    idCategorie       int                                   null,
    idSousCategorie   int                                   null,
    idVirement        int                                   null,
    montant           decimal(6, 2)                         not null,
    typeMouvement     char      default 'D'                 not null,
    dateHeureCreation timestamp default current_timestamp() not null,
    dateHeureMAJ      timestamp default current_timestamp() not null,
    constraint Mouvement_Categorie_idCategorie_fk
        foreign key (idCategorie) references Categories (idCategorie),
    constraint Mouvement_SousCategorie_idSousCategorie_fk
        foreign key (idSousCategorie) references SousCategories (idSousCategorie)
            on update cascade on delete set null,
    constraint Mouvement_Tiers_idTiers_fk
        foreign key (idTiers) references Tiers (idTiers),
    constraint Mouvement_Virement_idVirement_fk
        foreign key (idVirement) references Virements (idVirement)
            on update cascade on delete set null
);

DROP TRIGGER IF EXISTS TRG_BEFORE_UPDATE_CATEGORIE;
DROP TRIGGER IF EXISTS TRG_BEFORE_UPDATE_SOUS_CATEGORIE;
DROP TRIGGER IF EXISTS TRG_BEFORE_UPDATE_TIERS;
DROP TRIGGER IF EXISTS TRG_BEFORE_UPDATE_UTILISATEUR;
DROP TRIGGER IF EXISTS TRG_BEFORE_INSERT_MOUVEMENT;
DROP TRIGGER IF EXISTS TRG_BEFORE_UPDATE_VIREMENT;
DROP TRIGGER IF EXISTS TRG_AFTER_INSERT_VIREMENTS;
DROP TRIGGER IF EXISTS TRG_AFTER_DELETE_VIREMENT;

DELIMITER $$
create trigger TRG_BEFORE_UPDATE_CATEGORIE
    before update
    on Categories
    for each row
begin
    SET NEW.dateHeureMAJ = CURRENT_TIMESTAMP;
end;

$$

create trigger TRG_BEFORE_UPDATE_SOUS_CATEGORIE
    before update
    on SousCategories
    for each row
begin
    SET NEW.dateHeureMAJ = CURRENT_TIMESTAMP;
end;

$$

create trigger TRG_BEFORE_UPDATE_COMPTE
    before update
    on Comptes
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
    on Utilisateurs
    for each row
begin
    SET NEW.dateHeureMAJ = CURRENT_TIMESTAMP;
end;

$$

create trigger TRG_BEFORE_INSERT_MOUVEMENT
    before insert
    on Mouvements
    for each row
begin
    DEClARE v_Categorie INT DEFAULT 0;

    /* Il faut vérifier que la sous-catégorie appartient bien à la catégorie */
    IF NEW.idSousCategorie IS NOT NULL THEN
        SELECT idCategorie INTO v_Categorie FROM SousCategories WHERE idSousCategorie = NEW.idSousCategorie;
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
    on Virements
    for each row
begin
    SET NEW.dateHeureMAJ = CURRENT_TIMESTAMP;
end;

$$

create trigger TRG_AFTER_DELETE_VIREMENT
    after delete
    on Virements
    for each row
begin
    DELETE FROM Mouvements WHERE idVirement = OLD.idVirement;
end;

$$

CREATE TRIGGER TRG_AFTER_INSERT_VIREMENTS
AFTER INSERT ON Virements
FOR EACH ROW
BEGIN
  DECLARE idEpargne INT;

  -- Recherche de l'id de la catégorie "Épargne"
  SELECT idCategorie INTO idEpargne
  FROM Categories
  WHERE nomCategorie = 'Epargne'
  LIMIT 1;

  -- Insertion du mouvement débit (compte débité)
  INSERT INTO Mouvements(
      idCompte, montant, typeMouvement, idVirement, dateMouvement, idCategorie
  )
  VALUES (
      NEW.idCompteDebit, (NEW.montant * -1), 'D', NEW.idVirement, NEW.dateVirement, idEpargne
  );

  -- Insertion du mouvement crédit (compte crédité)
  INSERT INTO Mouvements(
      idCompte, montant, typeMouvement, idVirement, dateMouvement, idCategorie
  )
  VALUES (
      NEW.idCompteCredit, NEW.montant, 'C', NEW.idVirement, NEW.dateVirement, idEpargne
  );
END

$$

CREATE TRIGGER TRG_AFTER_INSERT_CATEGORIES
AFTER INSERT ON Categories
FOR EACH ROW
BEGIN
    INSERT INTO SousCategories (nomSousCategorie, idCategorie, dateHeureCreation, dateHeureMaj)
    VALUES ('Autres', NEW.idCategorie, NOW(), NOW());
END

$$

CREATE TRIGGER TRG_BEFORE_INSERT_MOUVEMENTS
BEFORE INSERT ON Mouvements
FOR EACH ROW
BEGIN
    DECLARE idAutres INT;

    -- Si aucune sous-catégorie n’est spécifiée
    IF NEW.idSousCategorie IS NULL THEN
        SELECT idSousCategorie INTO idAutres
        FROM SousCategories
        WHERE nomSousCategorie = 'Autres' AND idCategorie = NEW.idCategorie
        LIMIT 1;

        SET NEW.idSousCategorie = idAutres;
    END IF;
END

$$
