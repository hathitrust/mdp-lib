-- MySQL dump 10.9
--
-- Host: dev.mysql.umdl.umich.edu    Database: dlxs
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
  `collname` varchar(100) NOT NULL default '',
  `owner` varchar(32) default NULL,
  `description` varchar(255) default NULL,
  `num_items` int(11) default NULL,
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
INSERT INTO `test_collection` VALUES 
(8,'Stuff for English 324','tburtonw','Assignments for class and notes',1,1,0,'2007-06-20 17:43:13'),
(7,'Favorites','tburtonw','Collection of great stuff',1,0,0,'2007-06-20 17:41:42'),
(9,'Automotive Engineering','diabob','Everything I know about fixing cars',4,1,0,'2007-06-20 17:43:13'),
(10,'Book Illustrations','johnson','',27,1,0,'2007-06-20 17:43:13'),
(11,'Books and Stuff','tburtonw','',4,0,0,'2007-06-20 17:43:13');

UNLOCK TABLES;
/*!40000 ALTER TABLE `test_collection` ENABLE KEYS */;

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
  `rights` tinyint(3) unsigned default NULL,
  `bib_id` varchar(20) default NULL,
  PRIMARY KEY  (`item_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

--
-- Dumping data for table `test_item`
--
-- probably need to change rights to whatever they were in test db

/*!40000 ALTER TABLE `test_item` DISABLE KEYS */;
LOCK TABLES `test_item` WRITE;
INSERT INTO `test_item` VALUES 

(1,'mdp.39015020230051','The automobile hand-book; automobile hand-book;','automobile hand book','Brookes, Leonard Elliott, 1853-','1905-00-00','2010-05-06 13:47:03',1,'001627942'),

(2,'mdp.39015021038404','ChaufÃ¯eur chaff; or, Automobilia,','chaufÃ¯eur chaff or automobilia','Welsh, Charles, 1850-1914.','1905-00-00','2010-05-06 13:47:03',1,'001365383'),

(3,'mdp.39015002057589','Diseases of a gasolene automobile and how to cure them.','diseases of a gasolene automobile and how to cure them','Dyke, Andrew Lee, 1875-','1903-00-00','2010-05-06 13:47:03',1,'001620097'),

(4,'mdp.39015021302552','The happy motorist; an introduction to the use and enjoyment of the motor car. happy motorist; an in','happy motorist an introduction to the use and enjoyment of the motor car','Young, Filson, 1876-1938.','1906-00-00','2010-05-06 13:47:03',9,'002020420'),

(5,'mdp.39015021112043','The motor book, motor book,','motor book','Mercredy, R. J.','1903-00-00','2010-05-06 13:47:03',9,'001620103'),

(6,'mdp.39015021302602','The motor-car; an elementary handbook on its nature, use &amp; management. motor-car; an elementary','motor car an elementary handbook on its nature use management','Thompson, Henry, Sir, 1820-1904.','1902-00-00','2010-05-06 13:47:03',9,'002020403'),


(7,'mdp.39015021302586','Motor vehicles for business purposes; a practical handbook for those interested in the transport of','motor vehicles for business purposes a practical handbook for those interested in the transport of p','Wallis-Tayler, A. J. b. 1852.','1905-00-00','2010-05-06 13:47:03',9,'002434239'),

(8,'mdp.39015020229939','Self-propelled vehicles; a practical treatise on the theory, construction, operation, care and manag','self propelled vehicles a practical treatise on the theory construction operation care and managemen','Homans, James Edward, 1865-','1905-00-00','2010-05-06 13:47:03',1,'001627937'),

(9,'mdp.39015021057735','Tramways et automobiles,','tramways et automobiles','Aucamus, EugÃ¨ne.','1900-00-00','2010-05-06 13:47:03',9,'001612497'),


(10,'mdp.39015021054963','Tube, train, tram, and car, or, Up-to-date locomotion.','tube train tram and car or up to date locomotion','Beavan, Arthur Henry','1903-00-00','2010-05-06 13:47:03',9,'001612532'),

(11,'mdp.39015002056151','Whys and wherefores of the automobile, A simple explanation of the elements of the gasoline motor ca','whys and wherefores of the automobile a simple explanation of the elements of the gasoline motor car','Automobile institute, Cleveland, O.','1907-00-00','2010-05-06 13:47:03',1,'002020538'),


-- We need record with incorrect data to test updating metadata

(12,'39015021112043','BadTitle for update metadata,','motor book,','Author, BadforTest, K.','1903-00-00','2007-06-21 17:07:56','0','001620103');







UNLOCK TABLES;
/*!40000 ALTER TABLE `test_item` ENABLE KEYS */;


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
INSERT INTO `test_coll_item` VALUES (1,9),(2,9),(3,9),(3,11),(3,7),(3,8),(4,9),(4,11),(5,11),(6,11);
UNLOCK TABLES;
/*!40000 ALTER TABLE `test_coll_item` ENABLE KEYS */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;


-- MySQL dump 10.9
--
-- Host: localhost    Database: mdp
-- ------------------------------------------------------
-- Server version	4.1.10a

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;

-- MySQL dump 10.9
--
-- Host: localhost    Database: mdp
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
-- Table structure for table `test_index_queue`
--

DROP TABLE IF EXISTS `test_index_queue`;

CREATE TABLE `test_index_queue` (
  `time_added` datetime NOT NULL default '0000-00-00 00:00:00',
  `priority` int(6) NOT NULL default '0',
  `coll_ids` text character set latin1,
  `item_id` int(10) unsigned NOT NULL default '0',
  PRIMARY KEY  (`item_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

--
-- Dumping data for table `test_index_queue`
--


/*!40000 ALTER TABLE `test_index_queue` DISABLE KEYS */;
LOCK TABLES `test_index_queue` WRITE;
INSERT INTO `test_index_queue` VALUES 
('2008-04-15 13:20:26',1,'9|10|11',1),
('2008-04-15 13:20:27',1,'9|33',2),
('2008-04-15 13:20:28',100,'7|88|99',3),
('2008-04-15 13:20:29',100,'9|88',4),
('2008-04-15 13:20:30',100,'11|88',5),
('2008-04-15 13:20:31',2,'11',6);
UNLOCK TABLES;
/*!40000 ALTER TABLE `test_index_queue` ENABLE KEYS */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;



-- MySQL dump 10.9
--
-- Host: localhost    Database: mdp
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
-- Table structure for table `test_index_failures`
--

DROP TABLE IF EXISTS `test_index_failures`;
CREATE TABLE `test_index_failures` (
  `item_id` int(10) unsigned NOT NULL default '0',
  PRIMARY KEY  (`item_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;





--
-- Dumping data for table `test_index_failures`
--


/*!40000 ALTER TABLE `test_index_failures` DISABLE KEYS */;
LOCK TABLES `test_index_failures` WRITE;
INSERT INTO `test_index_failures` VALUES (1),(2),(4),(6);
UNLOCK TABLES;
/*!40000 ALTER TABLE `test_index_failures` ENABLE KEYS */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;


