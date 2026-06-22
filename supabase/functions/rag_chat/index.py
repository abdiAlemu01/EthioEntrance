import os
import json
from typing import List, Dict, Any
from supabase import create_client, Client
from langchain_openai import OpenAIEmbeddings, ChatOpenAI
from langchain_community.vectorstores import SupabaseVectorStore
from langchain.chains import RetrievalQA
from langchain.schema import Document
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Initialize Supabase client
supabase_url = os.environ.get("SUPABASE_URL")
supabase_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
openai_api_key = os.environ.get("OPENAI_API_KEY")

if not all([supabase_url, supabase_key, openai_api_key]):
    raise ValueError("Missing required environment variables")

supabase: Client = create_client(supabase_url, supabase_key)

# Initialize OpenAI embeddings and LLM
embeddings = OpenAIEmbeddings(openai_api_key=openai_api_key)
llm = ChatOpenAI(
    model_name="gpt-3.5-turbo",
    temperature=0.7,
    openai_api_key=openai_api_key
)

def similarity_search(query: str, grade: int = None, subject_id: str = None, k: int = 4) -> List[Document]:
    """
    Perform similarity search using pgvector
    """
    try:
        # Build the query filter
        filters = {}
        if grade:
            filters['grade'] = grade
        if subject_id:
            filters['subject_id'] = subject_id

        # Create vector store
        vector_store = SupabaseVectorStore(
            client=supabase,
            embedding=embeddings,
            table_name="embeddings",
            query_name="match_documents",
        )

        # Perform similarity search
        if filters:
            # Custom query with filters
            query_text = f"""
                SELECT 
                    e.id,
                    e.chunk_text,
                    e.metadata,
                    e.textbook_id,
                    t.title as textbook_title,
                    t.grade,
                    s.name as subject_name,
                    1 - (e.embedding <=> embedding) as similarity
                FROM embeddings e
                JOIN textbooks t ON e.textbook_id = t.id
                JOIN subjects s ON t.subject_id = s.id
                WHERE e.embedding <=> embedding
                {'AND t.grade = ' + str(grade) if grade else ''}
                {'AND t.subject_id = \'' + subject_id + '\'' if subject_id else ''}
                ORDER BY similarity DESC
                LIMIT {k}
            """
            
            # Get embedding for query
            query_embedding = embeddings.embed_query(query)
            
            # Execute query with embedding
            result = supabase.rpc('match_documents', {
                'query_embedding': query_embedding,
                'match_threshold': 0.5,
                'match_count': k
            })
            
            documents = []
            for row in result.data:
                metadata = {
                    'textbook_id': row['textbook_id'],
                    'textbook_title': row.get('textbook_title', ''),
                    'grade': row.get('grade'),
                    'subject_name': row.get('subject_name', ''),
                    'similarity': row.get('similarity', 0),
                    **row.get('metadata', {})
                }
                documents.append(Document(
                    page_content=row['chunk_text'],
                    metadata=metadata
                ))
            
            return documents
        else:
            # Simple similarity search without filters
            return vector_store.similarity_search(query, k=k)
            
    except Exception as e:
        print(f"Error in similarity search: {str(e)}")
        return []

def generate_rag_response(query: str, grade: int = None, subject_id: str = None) -> Dict[str, Any]:
    """
    Generate RAG response using retrieved context
    """
    try:
        # Retrieve relevant documents
        docs = similarity_search(query, grade=grade, subject_id=subject_id, k=4)
        
        if not docs:
            return {
                "response": "I don't have relevant information from the textbooks to answer your question. Please try rephrasing or ask about topics covered in the available materials.",
                "sources": []
            }
        
        # Build context from retrieved documents
        context_parts = []
        sources = []
        for i, doc in enumerate(docs):
            context_parts.append(f"[Source {i+1}]: {doc.page_content}")
            sources.append({
                "text": doc.page_content[:200] + "..." if len(doc.page_content) > 200 else doc.page_content,
                "textbook": doc.metadata.get('textbook_title', 'Unknown'),
                "subject": doc.metadata.get('subject_name', 'Unknown'),
                "grade": doc.metadata.get('grade'),
                "similarity": doc.metadata.get('similarity', 0)
            })
        
        context = "\n\n".join(context_parts)
        
        # Generate response using LLM with context
        prompt = f"""
        You are an educational assistant for Ethiopian students in grades 9-12. 
        Use the following textbook excerpts to answer the student's question accurately and helpfully.
        If the information is not in the context, say so clearly.
        
        Context from textbooks:
        {context}
        
        Student's question: {query}
        
        Provide a clear, educational answer suitable for the student's grade level.
        """
        
        response = llm.predict(prompt)
        
        return {
            "response": response,
            "sources": sources
        }
        
    except Exception as e:
        print(f"Error in generate_rag_response: {str(e)}")
        return {
            "response": f"Sorry, I encountered an error: {str(e)}",
            "sources": []
        }

def process_textbook(textbook_id: str, chunk_size: int = 1000, chunk_overlap: int = 200) -> Dict[str, Any]:
    """
    Process a textbook: extract text, create chunks, generate embeddings, and store in pgvector
    """
    try:
        # Get textbook info
        textbook_response = supabase.table('textbooks').select('*').eq('id', textbook_id).execute()
        if not textbook_response.data:
            return {"success": False, "error": "Textbook not found"}
        
        textbook = textbook_response.data[0]
        
        # Download textbook from storage
        # Note: This would require implementing PDF text extraction
        # For now, we'll assume the text is provided or extracted elsewhere
        
        # This is a placeholder - in production, you would:
        # 1. Download PDF from Supabase Storage
        # 2. Extract text using PyPDF2 or similar
        # 3. Chunk the text
        # 4. Generate embeddings
        # 5. Store in embeddings table
        
        return {
            "success": False,
            "error": "Textbook processing not fully implemented - requires PDF extraction setup"
        }
        
    except Exception as e:
        return {"success": False, "error": str(e)}

# Edge Function handler
def handler(event):
    """
    Main handler for the Edge Function
    """
    try:
        # Parse request body
        body = json.loads(event.get('body', '{}'))
        action = body.get('action', 'chat')
        
        if action == 'chat':
            # Handle chat request
            query = body.get('query', '')
            grade = body.get('grade')
            subject_id = body.get('subject_id')
            
            if not query:
                return {
                    'statusCode': 400,
                    'body': json.dumps({'error': 'Query is required'})
                }
            
            result = generate_rag_response(query, grade, subject_id)
            
            return {
                'statusCode': 200,
                'body': json.dumps(result)
            }
            
        elif action == 'process_textbook':
            # Handle textbook processing
            textbook_id = body.get('textbook_id')
            chunk_size = body.get('chunk_size', 1000)
            chunk_overlap = body.get('chunk_overlap', 200)
            
            if not textbook_id:
                return {
                    'statusCode': 400,
                    'body': json.dumps({'error': 'textbook_id is required'})
                }
            
            result = process_textbook(textbook_id, chunk_size, chunk_overlap)
            
            return {
                'statusCode': 200,
                'body': json.dumps(result)
            }
            
        else:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Invalid action'})
            }
            
    except Exception as e:
        print(f"Error in handler: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

# For local testing
if __name__ == "__main__":
    test_event = {
        'body': json.dumps({
            'action': 'chat',
            'query': 'What is photosynthesis?',
            'grade': 10,
            'subject_id': None
        })
    }
    result = handler(test_event)
    print(json.dumps(result, indent=2))
