-- MySQL dump 10.9
--
-- Host: dev.mysql    Database: dlxs
-- ------------------------------------------------------
-- Server version	4.1.10a

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;

--
-- Table structure for table `test_collection`
--

DROP TABLE IF EXISTS `test_collection`;
CREATE TABLE `test_collection` (
  `MColl_ID` int(10) unsigned NOT NULL auto_increment,
  `collname` varchar(100)  NOT NULL default '',
  `owner` varchar(15)  default NULL,
  `description` varchar(255)  default NULL,
  `nutest_items` int(11) default NULL,
  `shared` tinyint(1) default NULL,
  `indexed` tinyint(1) unsigned default NULL,
  `modified` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  PRIMARY KEY  (`MColl_ID`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

--
-- Dumping data for table `test_collection`
--


/*!40000 ALTER TABLE `test_collection` DISABLE KEYS */;
LOCK TABLES `test_collection` WRITE;
INSERT INTO `test_collection` VALUES (8,'Stuff for English 324','suzchap','Assignments for class and notes',1,1,0,'2007-06-20 17:43:13'),(7,'Favorites','suzchap','Collection of great stuff',27,0,0,'2007-06-20 17:41:42'),(9,'Automotive Engineering','diabob','Everything I know about fixing cars',125,1,0,'2007-06-20 17:43:13'),(10,'Book Illustrations','johnson','',27,1,0,'2007-06-20 17:43:13'),(11,'Books & Stuff','suzchap','',1,0,0,'2007-06-20 17:43:13');
UNLOCK TABLES;
/*!40000 ALTER TABLE `test_collection` ENABLE KEYS */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;

-- MySQL dump 10.9
--
-- Host: dev.mysql    Database: dlxs
-- ------------------------------------------------------
-- Server version	4.1.10a

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;

--
-- Table structure for table `test_coll_item`
--

DROP TABLE IF EXISTS `test_coll_item`;
CREATE TABLE `test_coll_item` (
  `item_id` int(10) unsigned NOT NULL default '0',
  `MColl_ID` int(10) unsigned NOT NULL default '0',
  PRIMARY KEY  (`item_id`,`MColl_ID`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

--
-- Dumping data for table `test_coll_item`
--


/*!40000 ALTER TABLE `test_coll_item` DISABLE KEYS */;
LOCK TABLES `test_coll_item` WRITE;
INSERT INTO `test_coll_item` VALUES (1,9),(2,9),(3,9),(3,11),(4,9),(4,11),(5,11),(6,11);
UNLOCK TABLES;
/*!40000 ALTER TABLE `test_coll_item` ENABLE KEYS */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;

-- MySQL dump 10.9
--
-- Host: dev.mysql    Database: dlxs
-- ------------------------------------------------------
-- Server version	4.1.10a

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;

--
-- Table structure for table `test_item`
--

DROP TABLE IF EXISTS `test_item`;
CREATE TABLE `test_item` (
  `item_id` int(10) unsigned NOT NULL auto_increment,
  `extern_item_id` varchar(255) NOT NULL default '',
  `display_title` varchar(100) default NULL,
  `sort_title` varchar(100) default NULL,
  `author` varchar(100) default NULL,
  `date` date default NULL,
  `modified` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  PRIMARY KEY  (`item_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

--
-- Dumping data for table `test_item`
--


/*!40000 ALTER TABLE `test_item` DISABLE KEYS */;
LOCK TABLES `test_item` WRITE;
INSERT INTO `test_item` VALUES (1,'39015020230051','The automobile hand-book;','The automobile hand-book;','Brookes, Leonard Elliott,','1905-01-01','2007-06-21 17:07:56'),(2,'39015021038404','ChaufÃ¯eur chaff; or, Automobilia,','ChaufÃ¯eur chaff; or, Automobilia,','Welsh, Charles,','1905-01-01','2007-06-21 17:07:56'),(3,'39015002057589','Diseases of a gasolene automobile and how to cure','Diseases of a gasolene automobile and how to cure','Dyke, Andrew Lee,','1903-01-01','2007-06-21 17:07:56'),(4,'39015021302552','The happy motorist; an introduction to the use','The happy motorist; an introduction to the use','Young, Filson,','1906-01-01','2007-06-21 17:07:56'),(5,'39015021112043','The motor book,','The motor book,','Mercredy, R. J.','1903-01-01','2007-06-21 17:07:56'),(6,'39015021302602','The motor-car; an elementary handbook on its','The motor-car; an elementary handbook on its','Thompson, Henry,','1902-01-01','2007-06-21 17:07:56'),(7,'39015021302586','Motor vehicles for business purposes; a practical','Motor vehicles for business purposes; a practical','Wallis-Tayler, A. J.','1905-01-01','2007-06-21 17:07:56'),(8,'39015020229939','Self-propelled vehicles; a practical treatise on','Self-propelled vehicles; a practical treatise on','Homans, James Edward,','1905-01-01','2007-06-21 17:07:56'),(9,'39015021057735','Tramways et automobiles,','Tramways et automobiles,','Galine, L.','1900-01-01','2007-06-21 17:07:56'),(10,'39015021054963','Tube, train, tram, and car, or, Up-to-date','Tube, train, tram, and car, or, Up-to-date','Beavan, Arthur Henry','1903-01-01','2007-06-21 17:07:56'),(11,'39015002056151','Whys and wherefores of the automobile, A simple','Whys and wherefores of the automobile, A simple','Automobile institute, Cleveland, O.','1907-01-01','2007-06-21 17:07:56');
UNLOCK TABLES;
/*!40000 ALTER TABLE `test_item` ENABLE KEYS */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;

