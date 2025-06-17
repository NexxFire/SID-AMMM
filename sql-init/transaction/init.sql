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

INSERT INTO Categorie (nomCategorie, dateHeureMAJ, dateHeureCreation) VALUES ('Alimentation', NOW(), NOW()),  ('Transports', NOW(),NOW());
INSERT INTO SousCategorie (nomSousCategorie, idCategorie, dateHeureMAJ, dateHeureCreation) VALUES ('Courses', 1, NOW(), NOW()), ('Essence', 2, NOW(), NOW());
INSERT INTO Utilisateur (nomUtilisateur, prenomUtilisateur, login, mdp, dateHeureCreation, dateHeureMAJ, ville, codePostal) VALUES ('BULTEZ', 'Matheo', 'mbultez','$argon2id$v=19$m=65536,t=3,p=4$2xexgNpDhqAhFRDcpLDp9Q$fh6HhyOD1bWbGl45it5L1nWz6fFP6lHoaSOIFK6eigs',NOW(),NOW(),'Labeuvriere', '62122');
INSERT INTO Compte (descriptionCompte, nomBanque,idUtilisateur, dateHeureMAJ,dateHeureCreation) VALUES ('Compte Courant','BNP',1, NOW(),NOW());
INSERT INTO Tiers (nomTiers, dateHeureMAJ,dateHeureCreation,idUtilisateur) VALUES ('Supermarché', NOW(),NOW(),1);

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
            SET MESSAGE_TEXT = 'La sous-catégorie n\'appartient pas à la catégorie choisie';
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