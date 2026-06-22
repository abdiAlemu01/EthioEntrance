-- EthioEntrance Supabase Database Setup
-- This SQL script sets up the database schema for the EthioEntrance E-learning app
-- with RAG capabilities using pgvector

-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Create profiles table (extends Supabase auth.users)
CREATE TABLE IF NOT EXISTS profiles (
    id UUID REFERENCES auth.users(id) PRIMARY KEY,
    email TEXT,
    first_name TEXT,
    last_name TEXT,
    grade INTEGER CHECK (grade IN (9, 10, 11, 12)),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

-- Create subjects table
CREATE TABLE IF NOT EXISTS subjects (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    subject_code TEXT UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

-- Create textbooks table
CREATE TABLE IF NOT EXISTS textbooks (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    subject_id UUID REFERENCES subjects(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    grade INTEGER CHECK (grade IN (9, 10, 11, 12)),
    file_path TEXT NOT NULL, -- Storage path in Supabase Storage
    file_url TEXT, -- Public URL
    file_size BIGINT,
    page_count INTEGER,
    uploaded_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    processed BOOLEAN DEFAULT FALSE, -- Whether text has been extracted and embedded
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

-- Create embeddings table with pgvector
CREATE TABLE IF NOT EXISTS embeddings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    textbook_id UUID REFERENCES textbooks(id) ON DELETE CASCADE,
    chunk_text TEXT NOT NULL,
    embedding vector(1536), -- OpenAI embedding dimension
    chunk_index INTEGER NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

-- Create videos table
CREATE TABLE IF NOT EXISTS videos (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    subject_id UUID REFERENCES subjects(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    grade INTEGER CHECK (grade IN (9, 10, 11, 12)),
    file_path TEXT NOT NULL,
    file_url TEXT,
    duration INTEGER, -- in seconds
    uploaded_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

-- Create chat_history table for AI conversations
CREATE TABLE IF NOT EXISTS chat_history (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    is_user BOOLEAN NOT NULL,
    context_sources JSONB DEFAULT '[]'::jsonb, -- Sources used for RAG
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_embeddings_textbook_id ON embeddings(textbook_id);
CREATE INDEX IF NOT EXISTS idx_embeddings_chunk_index ON embeddings(chunk_index);
CREATE INDEX IF NOT EXISTS idx_textbooks_subject_id ON textbooks(subject_id);
CREATE INDEX IF NOT EXISTS idx_textbooks_grade ON textbooks(grade);
CREATE INDEX IF NOT EXISTS idx_videos_subject_id ON videos(subject_id);
CREATE INDEX IF NOT EXISTS idx_videos_grade ON videos(grade);
CREATE INDEX IF NOT EXISTS idx_chat_history_user_id ON chat_history(user_id);
CREATE INDEX IF NOT EXISTS idx_chat_history_created_at ON chat_history(created_at DESC);

-- Create vector similarity search index
CREATE INDEX IF NOT EXISTS idx_embeddings_embedding ON embeddings 
USING ivfflat (embedding vector_cosine_ops) 
WITH (lists = 100);

-- Enable Row Level Security (RLS)
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE textbooks ENABLE ROW LEVEL SECURITY;
ALTER TABLE embeddings ENABLE ROW LEVEL SECURITY;
ALTER TABLE videos ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_history ENABLE ROW LEVEL SECURITY;

-- RLS Policies for profiles
CREATE POLICY "Users can view all profiles" ON profiles
    FOR SELECT USING (true);
    
CREATE POLICY "Users can insert their own profile" ON profiles
    FOR INSERT WITH CHECK (auth.uid() = id);
    
CREATE POLICY "Users can update their own profile" ON profiles
    FOR UPDATE USING (auth.uid() = id);

-- RLS Policies for subjects (public read)
CREATE POLICY "Anyone can view subjects" ON subjects
    FOR SELECT USING (true);

-- RLS Policies for textbooks
CREATE POLICY "Anyone can view textbooks" ON textbooks
    FOR SELECT USING (true);
    
CREATE POLICY "Authenticated users can upload textbooks" ON textbooks
    FOR INSERT WITH CHECK (auth.uid() = uploaded_by);
    
CREATE POLICY "Textbook uploader can update their textbooks" ON textbooks
    FOR UPDATE USING (auth.uid() = uploaded_by);

-- RLS Policies for embeddings
CREATE POLICY "Anyone can view embeddings" ON embeddings
    FOR SELECT USING (true);
    
CREATE POLICY "Service role can manage embeddings" ON embeddings
    FOR ALL USING (auth.role() = 'service_role');

-- RLS Policies for videos
CREATE POLICY "Anyone can view videos" ON videos
    FOR SELECT USING (true);
    
CREATE POLICY "Authenticated users can upload videos" ON videos
    FOR INSERT WITH CHECK (auth.uid() = uploaded_by);
    
CREATE POLICY "Video uploader can update their videos" ON videos
    FOR UPDATE USING (auth.uid() = uploaded_by);

-- RLS Policies for chat_history
CREATE POLICY "Users can view their own chat history" ON chat_history
    FOR SELECT USING (auth.uid() = user_id);
    
CREATE POLICY "Users can insert their own chat messages" ON chat_history
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Create function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = TIMEZONE('utc', NOW());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for updated_at
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_subjects_updated_at BEFORE UPDATE ON subjects
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_textbooks_updated_at BEFORE UPDATE ON textbooks
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_videos_updated_at BEFORE UPDATE ON videos
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Create function to handle new user signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO profiles (id, email, first_name, last_name)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'first_name', ''),
        COALESCE(NEW.raw_user_meta_data->>'last_name', '')
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for new user signup
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Insert sample subjects
INSERT INTO subjects (name, subject_code, description) VALUES
    ('Mathematics', 'MATH', 'Mathematics courses for grades 9-12'),
    ('Physics', 'PHYS', 'Physics courses for grades 9-12'),
    ('Chemistry', 'CHEM', 'Chemistry courses for grades 9-12'),
    ('Biology', 'BIO', 'Biology courses for grades 9-12'),
    ('English', 'ENG', 'English language and literature'),
    ('Amharic', 'AMH', 'Amharic language and literature'),
    ('Civics', 'CIV', 'Civic and ethical education'),
    ('History', 'HIST', 'History courses'),
    ('Geography', 'GEOG', 'Geography courses'),
    ('Economics', 'ECON', 'Economics courses for grades 11-12')
ON CONFLICT (subject_code) DO NOTHING;

-- Create storage buckets (run these in Supabase dashboard or via API)
-- Bucket: textbooks
-- Bucket: videos
-- Bucket: profiles

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO anon, authenticated;
