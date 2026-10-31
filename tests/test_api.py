import unittest
import server

class PackageSmokeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls): server.init_db()
    def test_database_counts(self):
        with server.conn() as c:
            self.assertGreater(c.execute('select count(*) from colleges').fetchone()[0],0)
            self.assertGreater(c.execute('select count(*) from cutoffs').fetchone()[0],0)
    def test_cutoff_metric_fields(self):
        with server.conn() as c: cols={r[1] for r in c.execute('pragma table_info(cutoffs)')}
        self.assertIn('min_cutoff_numeric',cols); self.assertIn('max_cutoff_numeric',cols)
    def test_data_quality_discloses_limitations(self):
        self.assertIn('No verified 2026 final cutoff dataset',server.quality()['limitations'])
    def test_startup_does_not_destroy_database(self):
        with server.conn() as c: before=c.execute('select count(*) from colleges').fetchone()[0]
        server.init_db()
        with server.conn() as c: after=c.execute('select count(*) from colleges').fetchone()[0]
        self.assertEqual(before,after)
    def test_branch_and_fee_tables_exist(self):
        with server.conn() as c:
            self.assertGreater(c.execute('select count(*) from branches').fetchone()[0],0)
            self.assertGreater(c.execute('select count(*) from fees').fetchone()[0],0)

if __name__=='__main__': unittest.main()
