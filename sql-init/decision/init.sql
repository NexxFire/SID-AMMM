CREATE TABLE `Catégorie` (
  `id` integer PRIMARY KEY AUTO_INCREMENT,
  `nom` varchar(255),
  `dateHeureCréation` datetime,
  `dateHeureMaj` datetime
);

CREATE TABLE `SousCatégorie` (
  `id` integer PRIMARY KEY AUTO_INCREMENT,
  `nom` varchar(255),
  `dateHeureCréation` datetime,
  `dateHeureMaj` datetime,
  `idCatégorie` integer
);

CREATE TABLE `Soldes` (
  `id` integer PRIMARY KEY AUTO_INCREMENT,
  `solde` float,
  `date` datetime,
  `compte` boolean
);

CREATE TABLE `Temps` (
  `id` integer PRIMARY KEY AUTO_INCREMENT,
  `nom` varchar(255),
  `mois` integer,
  `année` integer,
  `moisAnnée` varchar(255)
);

CREATE TABLE `Transactions` (
  `id` integer PRIMARY KEY AUTO_INCREMENT,
  `montant` float,
  `date` datetime,
  `type` varchar(255),
  `idCatégorie` integer,
  `idSousCatégorie` integer,
  `nomTiers` varchar(255),
  `compte` boolean
);

CREATE TABLE `Compte` (
  `id` integer PRIMARY KEY AUTO_INCREMENT,
  `banque` varchar(255),
  `description` varchar(255)
);

CREATE TABLE `Virement` (
  `id` integer PRIMARY KEY AUTO_INCREMENT,
  `idCompteCréditeur` integer,
  `idCompteDébiteur` integer,
  `montant` integer,
  `date` datetime
);

ALTER TABLE `Soldes` ADD FOREIGN KEY (`date`) REFERENCES `Temps` (`id`);

ALTER TABLE `Soldes` ADD FOREIGN KEY (`compte`) REFERENCES `Compte` (`id`);

ALTER TABLE `Virement` ADD FOREIGN KEY (`date`) REFERENCES `Temps` (`id`);

ALTER TABLE `Virement` ADD FOREIGN KEY (`idCompteCréditeur`) REFERENCES `Compte` (`id`);

ALTER TABLE `Virement` ADD FOREIGN KEY (`idCompteDébiteur`) REFERENCES `Compte` (`id`);

ALTER TABLE `Transactions` ADD FOREIGN KEY (`date`) REFERENCES `Temps` (`id`);

ALTER TABLE `Transactions` ADD FOREIGN KEY (`compte`) REFERENCES `Compte` (`id`);

ALTER TABLE `Transactions` ADD FOREIGN KEY (`idCatégorie`) REFERENCES `Catégorie` (`id`);

ALTER TABLE `Transactions` ADD FOREIGN KEY (`idSousCatégorie`) REFERENCES `SousCatégorie` (`id`);
