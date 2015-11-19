import math

class DiskImage(object):
    '''Low-level manipulation of PEDISK disk image data.  Seek to track/
    sector positions with boundary checks and read/write raw data in the
    image.  This class is abstract.'''
    SECTOR_SIZE = 128
    TRACKS = None  # override in subclass
    SECTORS = None  # override in subclass

    def __init__(self):
        self.TOTAL_SIZE = self.SECTOR_SIZE * self.SECTORS * self.TRACKS
        self.data = bytearray(b'\xE5' * self.TOTAL_SIZE)
        self.home()

    def home(self):
        '''Seek to the first sector of the first track'''
        self.seek(track=0, sector=1)

    def seek(self, track, sector):
        '''Seek to the given track/sector position.  As with the IBM 3740
        numbering, tracks are 0-based, sectors are 1-based.'''
        self._validate_ts(track, sector)
        self.track = 0
        self.sector = 1
        self.sector_offset = 0
        self.data_offset = 0
        while (self.track != track) or (self.sector != sector):
            self._incr()

    def write(self, data):
        '''Write a bytearray of arbitrary length starting at the current
        position.  The data can span sectors and tracks.  Track/sector is
        advanced past the data written.  Raises an error if the data
        exceeds the end of the image.'''
        wrapped = False
        for d in data:
            if wrapped:
                raise ValueError("Wrote past end of disk")
            self.data[self.data_offset] = d
            wrapped = self._incr()

    def read(self, numbytes):
        '''Read a bytearray of arbitrary length starting at the current
        position.  The data can span sectors and tracks.  Track/sector is
        advanced past the data read.  Raises an error if the data exceeds
        the end of the image.'''
        wrapped = False
        data = bytearray()
        for n in range(numbytes):
            if wrapped:
                raise ValueError("Read past end of disk")
            d = self.data[self.data_offset]
            data.append(d)
            wrapped = self._incr()
        return data

    def _validate_ts(self, track, sector):
        '''Raise ValueError if track/sector is out of range'''
        if (track < 0) or (track >= self.TRACKS):
            msg = 'Track %r not in range 0-%d' % (track, self.TRACKS-1)
            raise ValueError(msg)
        if (sector < 1) or (sector > self.SECTORS):
            msg = 'Sector %r not in range 1-%d' % (sector, self.SECTORS)
            raise ValueError(msg)

    def _incr(self):
        '''Increment the current track, sector, and image position pointers
        by one byte.  Returns True if wrapped around the disk.'''
        wrapped = False
        self.data_offset += 1
        self.sector_offset += 1
        if self.sector_offset == self.SECTOR_SIZE:
            self.sector_offset = 0
            self.sector += 1
            if self.sector > self.SECTORS:
                self.sector = 1
                self.track += 1
                if self.track == self.TRACKS:
                    wrapped = True
                    self.data_offset = 0
                    self.track = 0
                    self.sector = 1
        return wrapped

class FiveInchDiskImage(DiskImage):
    '''5.25" disk'''
    TRACKS = 41 # tracks numbered 0-40
    SECTORS = 28 # sectors per track numbered 1-28

class EightInchDiskImage(DiskImage):
    '''8" disk'''
    TRACKS = 77 # tracks numbered 0-76
    SECTORS = 26 # sectors per track numbered 1-26

class Filesystem(object):
    '''High-level manipulation of the filesystem on a PEDISK disk image'''

    def __init__(self, image):
        '''image is a DiskImage object'''
        self.image = image

    def format(self, diskname):
        '''Completely erase the disk image and write an empty directory'''
        if len(diskname) > 8:
            msg = 'Disk name %r is too long, limit is 8 bytes' % diskname
            raise ValueError(msg)

        # initialize the entire image to 0xE5
        self.image.home()
        self.image.write(b'\xe5' * self.image.TOTAL_SIZE)

        # write directory header (16 bytes)
        self.image.home()
        self.image.write(diskname.ljust(8, b'\x20')) # 8 bytes
        self.image.write(b'\x00') # number of used files (includes deleted)
        self.image.write(b'\x00') # next open track (track 0)
        self.image.write(b'\x09') # next open sector (sector 9)
        self.image.write(b'\x20' * 5) # 5 unused bytes, always 0x20

        # write directory entries (63 entries of 16 bytes each)
        self.image.write(b'\xff' * 63 * 16)

    @property
    def next_free_ts(self):
        '''Read the directory header and return the next available track
        and sector where a new file can be stored.  Raises if the directory
        header is invalid.  Returns (track, sector).'''
        self.image.seek(track=0, sector=1)
        self.image.read(8) # skip diskname
        self.image.read(1) # skip number of files

        track = ord(self.image.read(1))
        sector = ord(self.image.read(1))

        # check track in range of image
        if track > (self.image.TRACKS - 1):
            msg = ('Directory invalid: next available track %d '
                   'not in range 0-%d' % (track, self.image.TRACKS - 1))
            raise ValueError(msg)

        # check sector in range of image
        if (sector < 1) or (sector > self.image.SECTORS):
            msg = ('Directory invalid: next available sector %d '
                   'not in range 1-%d' % (sector, self.image.SECTORS))
            raise ValueError(msg)

        # check (track, sector) is not in the directory area
        if (track == 0) and (sector < 9):
            msg = ('Directory invalid: next available track %d, sector %d '
                   'is inside the directory area' % (track, sector))
            raise ValueError(msg)

        return track, sector

    @property
    def num_used_entries(self):
        '''Read the directory header and return the number of file entries
        used (includes deleted).'''
        self.image.seek(track=0, sector=1)
        self.image.read(8) # skip diskname
        entries_used = ord(self.image.read(1))

        if entries_used > 63:
            msg = ('Directory invalid: directory entry count byte of %d '
                   'not in range 0-63' % entries_used)
            raise ValueError(msg)

        return entries_used

    def seek_to_free_entry(self):
        '''Seek to the next free directory entry.  Raises an
        error if no more entries are available.'''
        if self.num_free_entries == 0:
            raise ValueError('Disk full: no entries left in directory')

        used_entries = self.num_used_entries
        self.image.home()
        self.image.read(16) # skip past directory header
        for i in range(used_entries):
            self.image.read(16) # skip past used entry

    @property
    def num_free_entries(self):
        '''Read the directory header and return the number of directory
        entries available for new files.'''
        return 63 - self.num_used_entries

    @property
    def num_free_sectors(self):
        '''Read the directory header and return the number of sectors
        available for new files'''
        track, sector = self.next_free_ts

        # start with 1 (this is the sector return by next_free_ts)
        free_sectors = 1

        # add all the higher sectors on the same track
        free_sectors += self.image.SECTORS - sector

        # add all the sectors on all the higher tracks
        num_empty_tracks = self.image.TRACKS - track - 1
        free_sectors += num_empty_tracks * self.image.SECTORS

        return free_sectors

    @property
    def num_free_bytes(self):
        '''Read the directory header and return the number of bytes
        available for new files'''
        return self.num_free_sectors * self.image.SECTOR_SIZE

    def list_dir(self):
        '''Read the directory and return a list of active filenames'''
        return [ e.filename for e in self.read_dir() if e.active ]

    def read_dir(self):
        '''Read the directory and return all entries.  This includes
        deleted and unused entries.'''
        self.image.home()
        self.image.read(16) # skip directory header
        entries = []
        for i in range(63):
            data = self.image.read(16)
            entry = DirectoryEntry.from_bytes(data)
            entries.append(entry)
        return entries

    def read_entry(self, filename):
        '''Read the directory and return the entry for the given filename.
        The entry can be a deleted or unused one.  An exception is raised
        if the file is not found'''
        filename = filename.ljust(6, b'\x20')
        for entry in self.read_dir():
            if entry.filename == filename:
                return entry
        raise ValueError("File %r not found" % filename)

    def read_file(self, filename):
        '''Read the contents of the file with the given filename.  An
        exception is raised if the file is not found.'''
        entry = self.read_entry(filename)
        self.image.seek(track=entry.track, sector=entry.sector)
        if entry.filetype == FileTypes.LD:
            size = entry.sector_count * self.image.SECTOR_SIZE
            return self.image.read(size)
        else:
            return self.image.read(entry.size)

    def write_file(self, filename, filetype, size, load_address, data):
        # check if file will fit in free sectors left on disk
        if len(data) > self.num_free_bytes:
            msg = ('Disk full: data is %d bytes, free space is only '
                   '%d bytes' % (len(data), self.num_free_bytes))
            raise ValueError(msg)

        # find location for new file
        track, sector = self.next_free_ts

        # find number of sectors required for file
        sector_count = len(data) / float(self.image.SECTOR_SIZE)
        sector_count = int(math.ceil(sector_count))

        # write directory entry
        self.seek_to_free_entry()
        entry = DirectoryEntry(
            filename=filename,
            size=size,
            load_address=load_address,
            filetype=filetype,
            track=track,
            sector=sector,
            sector_count=sector_count
            )
        self.image.write(entry.to_bytes())

        # write file padded with 0xE5 so it completely fills the sectors
        data = data.ljust(sector_count * self.image.SECTOR_SIZE, b'\xe5')
        self.image.seek(track, sector)
        self.image.write(data)

        # next free track/sector after the file we just wrote
        track = self.image.track
        sector = self.image.sector

        # update directory header
        used_entries = self.num_used_entries + 1
        self.image.home()
        self.image.read(8) # skip disk name
        self.image.write(bytearray([used_entries]))
        self.image.write(bytearray([track, sector]))

def _low_high(num):
    '''Split an unsigned 16-bit number into two 8-bit numbers: (low, high)'''
    if num < 0 or num > 65535:
        raise ValueError('Expected 0-65535, got %r' % num)
    low = num & 0xFF
    high = num >> 8
    return low, high

class FileTypes(object):
    '''File types supported by the PEDISK file system'''
    SEQ = 0x00
    IND = 0x01
    ISM = 0x02
    BAS = 0x03
    ASM = 0x04
    LD  = 0x05
    TXT = 0x06
    OBJ = 0x07

    @classmethod
    def name_of(klass, number):
        '''Get the string name for a file type (e.g. "BAS" for 3)'''
        for k, v in klass.__dict__.items():
            if not k.startswith('_') and v == number:
                return k
        raise IndexError('File type number not found: %r' % number)

class DirectoryEntry(object):
    def __init__(self, filename, filetype, size,
                 load_address, track, sector, sector_count):
        self.filename = filename            # 6 bytes
        self.filetype = filetype            # 1 byte
        self.size = size                    # 2 bytes
        self.load_address = load_address    # 2 bytes
        self.track = track                  # 1 byte
        self.sector = sector                # 1 byte
        self.sector_count = sector_count    # 2 bytes
                                            # +1 unused = 16 bytes
    @classmethod
    def from_bytes(klass, data):
        return klass(
            filename=data[0:6],
            size=data[6] + (data[7] << 8),
            load_address=data[8] + (data[9] << 8),
            filetype=data[10],
            track=data[12],
            sector=data[13],
            sector_count=data[14] + (data[15] << 8)
            )

    def to_bytes(self):
        self._validate()
        data = bytearray()
        data.extend(self.filename.ljust(6, b'\x20'))
        data.extend(_low_high(self.size))
        data.extend(_low_high(self.load_address))
        data.append(self.filetype)
        data.append(0x20) # unused byte, always 0x20
        data.extend([self.track, self.sector])
        data.extend(_low_high(self.sector_count))
        return data

    @property
    def active(self):
        return self.filename[0] != 0xFF

    def _validate(self):
        if len(self.filename) < 1 or len(self.filename) > 6:
            msg = ('Invalid filename: %r is not between '
                   '1 and 6 bytes' % self.filename)
            raise ValueError(msg)
