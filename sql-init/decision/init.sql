CREATE TABLE `Temps` (
  `id` INT PRIMARY KEY AUTO_INCREMENT,
  `date` DATE,
  `jour` INT NOT NULL,
  `mois` INT NOT NULL,
  `annee` INT NOT NULL,
  `jourJulien` INT,
  `nomJour` VARCHAR(255)
);

CREATE TABLE `Comptes` (
  `id` INT PRIMARY KEY AUTO_INCREMENT,
  `banque` VARCHAR(255) NOT NULL,
  `description` VARCHAR(255)
);

CREATE TABLE `Categories` (
  `id` INT PRIMARY KEY AUTO_INCREMENT,
  `nom` VARCHAR(255) NOT NULL
);

CREATE TABLE `SousCategories` (
  `id` INT PRIMARY KEY AUTO_INCREMENT,
  `nom` VARCHAR(255) NOT NULL,
  `idCategorie` INT,
  FOREIGN KEY (`idCategorie`) REFERENCES `Categories` (`id`) ON DELETE SET NULL
);

CREATE TABLE `Soldes` (
  `id` INT PRIMARY KEY AUTO_INCREMENT,
  `solde` DECIMAL(10, 2) NOT NULL,
  `idDate` INT,
  `idCompte` INT,
  FOREIGN KEY (`idDate`) REFERENCES `Temps` (`id`) ON DELETE SET NULL,
  FOREIGN KEY (`idCompte`) REFERENCES `Comptes` (`id`) ON DELETE SET NULL
);

CREATE TABLE `Transactions` (
  `id` INT PRIMARY KEY AUTO_INCREMENT,
  `montant` DECIMAL(10, 2) NOT NULL,
  `idDate` INT,
  `type` VARCHAR(255),
  `idCategorie` INT,
  `idSousCategorie` INT,
  `nomTiers` VARCHAR(255),
  `idCompte` INT,
  FOREIGN KEY (`idDate`) REFERENCES `Temps` (`id`) ON DELETE SET NULL,
  FOREIGN KEY (`idCategorie`) REFERENCES `Categories` (`id`) ON DELETE SET NULL,
  FOREIGN KEY (`idSousCategorie`) REFERENCES `SousCategories` (`id`) ON DELETE SET NULL,
  FOREIGN KEY (`idCompte`) REFERENCES `Comptes` (`id`) ON DELETE SET NULL
);

CREATE TABLE `Virements` (
  `id` INT PRIMARY KEY AUTO_INCREMENT,
  `idCompteCrediteur` INT,
  `idCompteDebiteur` INT,
  `montant` DECIMAL(10, 2) NOT NULL,
  `idDate` INT,
  FOREIGN KEY (`idCompteCrediteur`) REFERENCES `Comptes` (`id`) ON DELETE SET NULL,
  FOREIGN KEY (`idCompteDebiteur`) REFERENCES `Comptes` (`id`) ON DELETE SET NULL,
  FOREIGN KEY (`idDate`) REFERENCES `Temps` (`id`) ON DELETE SET NULL
);